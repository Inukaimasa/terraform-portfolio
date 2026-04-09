# short_code ごとのアクセス記録と集計取得を行う analytics Lambda。
# 処理のスタートは lambda_handler(event, context)。
# redirect Lambda からの呼び出しでは DynamoDB に日別集計を保存し、
# API Gateway の GET/POST では集計取得または手動記録を行う。

import json
import logging
import os
from datetime import datetime, timedelta, timezone
# DynamoDB の数値は Decimal 型で返ってくることがある
# そのため、Decimal を int や float に変換するために使う
from decimal import Decimal

import boto3
# DynamoDB の query で条件を書くために使う
# 特に「PK がこれ」「SK がこの範囲」という検索条件を組み立てるときに使う
from boto3.dynamodb.conditions import Key
# boto3 で AWS サービスを呼んだときに起きる代表的なエラーを受けるために使う
# たとえば DynamoDB の読み取り / 更新 / query に失敗したときに発生する
from botocore.exceptions import ClientError

# CloudWatch Logs に出すための logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# DynamoDB を操作するための入口
dynamodb = boto3.resource("dynamodb")

# 環境変数から集計テーブル名を取得
# 例: ACCESS_SUMMARY_TABLE_NAME=access_summary
ACCESS_SUMMARY_TABLE_NAME = os.environ["ACCESS_SUMMARY_TABLE_NAME"]

# 集計テーブルを使える形にする
access_summary_table = dynamodb.Table(ACCESS_SUMMARY_TABLE_NAME)


def json_default(obj):
    """
    DynamoDB から返る Decimal 型を JSON に変換するための関数。

    DynamoDB の数値は Decimal で返ることがあるため、
    json.dumps の default にこの関数を渡して変換する。
    """
    if isinstance(obj, Decimal):
        if obj % 1 == 0:
            return int(obj)
        return float(obj)
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")


def json_response(status_code: int, body: dict) -> dict:
    """
    API Gateway に返す JSON レスポンスを作る共通関数。
    """
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json; charset=utf-8",
        },
        "body": json.dumps(body, ensure_ascii=False, default=json_default),
    }


def get_http_method(event: dict) -> str | None:
    """
    API Gateway の event から HTTP メソッドを取得する。

    HTTP API と REST API で event の形が少し違うので、
    両方に対応できるようにしている。
    """
    request_context = event.get("requestContext") or {}
    http_info = request_context.get("http") or {}
    return http_info.get("method") or event.get("httpMethod")


def parse_body(event: dict) -> dict:
    """
    event["body"] を Python の dict に変換する。

    - body がなければ空 dict
    - body がすでに dict ならそのまま返す
    - JSON文字列なら json.loads で変換
    - JSON変換できなければ空 dict
    """
    body = event.get("body")
    if not body:
        return {}

    if isinstance(body, dict):
        return body

    try:
        return json.loads(body)
    except json.JSONDecodeError:
        return {}


def iso_to_date_string(iso_value: str | None) -> str:
    """
    ISO形式の日時文字列から YYYY-MM-DD を取り出す。

    例:
    2026-04-09T12:34:56+00:00 -> 2026-04-09

    値がない、または変換できない場合は今日の日付を返す。
    """
    if not iso_value:
        return datetime.now(timezone.utc).date().isoformat()

    try:
        dt = datetime.fromisoformat(iso_value.replace("Z", "+00:00"))
        return dt.astimezone(timezone.utc).date().isoformat()
    except ValueError:
        return datetime.now(timezone.utc).date().isoformat()


def record_access(payload: dict) -> dict:
    """
    アクセス記録を DynamoDB に保存 / 加算する関数。

    想定 payload:
    {
        "short_code": "abc123",
        "creator_id": "creator001",
        "link_id": "link001",
        "accessed_at": "2026-04-09T12:34:56+00:00",
        "user_agent": "...",
        "referer": "...",
        "source_ip": "..."
    }

    保存先のキー:
    PK = LINK#short_code
    SK = DATE#YYYY-MM-DD

    同じ short_code + 同じ日付 のデータに対して access_count を加算する。
    """
    short_code = payload.get("short_code")
    if not short_code:
        return {"ok": False, "message": "short_code is required"}

    # 何日のアクセスとして集計するか
    access_date = iso_to_date_string(payload.get("accessed_at"))

    # 最終アクセス日時として保存する値
    now_iso = payload.get("accessed_at") or datetime.now(timezone.utc).isoformat()

    # DynamoDB の主キー
    pk = f"LINK#{short_code}"
    sk = f"DATE#{access_date}"

    try:
        access_summary_table.update_item(
            Key={
                "PK": pk,
                "SK": sk,
            },
            UpdateExpression="""
                SET
                    short_code = if_not_exists(short_code, :short_code),
                    creator_id = if_not_exists(creator_id, :creator_id),
                    link_id = if_not_exists(link_id, :link_id),
                    last_accessed_at = :last_accessed_at,
                    user_agent = :user_agent,
                    referer = :referer,
                    source_ip = :source_ip
                ADD access_count :inc
            """,
            ExpressionAttributeValues={
                ":short_code": short_code,
                ":creator_id": payload.get("creator_id") or "",
                ":link_id": payload.get("link_id") or "",
                ":last_accessed_at": now_iso,
                ":user_agent": payload.get("user_agent") or "",
                ":referer": payload.get("referer") or "",
                ":source_ip": payload.get("source_ip") or "",
                ":inc": 1,
            },
        )
    except ClientError:
        logger.exception("Failed to update access summary.")
        return {"ok": False, "message": "Failed to update access summary"}

    return {
        "ok": True,
        "message": "Access recorded",
        "short_code": short_code,
        "date": access_date,
    }


def get_query_param(event: dict, key: str) -> str | None:
    """
    queryStringParameters から指定キーの値を取得する。
    例: ?shortCode=abc123
    """
    params = event.get("queryStringParameters") or {}
    return params.get(key)


def get_path_param(event: dict, key: str) -> str | None:
    """
    pathParameters から指定キーの値を取得する。
    例: /analytics/abc123 のようなルートを使う場合に利用できる。
    """
    params = event.get("pathParameters") or {}
    return params.get(key)


def list_access_summary(short_code: str, start_date: str, end_date: str) -> dict:
    """
    指定した short_code の日別アクセス集計を取得する。

    例:
    short_code = abc123
    start_date = 2026-04-01
    end_date   = 2026-04-09
    """
    pk = f"LINK#{short_code}"
    start_sk = f"DATE#{start_date}"
    end_sk = f"DATE#{end_date}"

    try:
        response = access_summary_table.query(
            KeyConditionExpression=Key("PK").eq(pk) & Key("SK").between(start_sk, end_sk),
            ScanIndexForward=True,
        )
        items = response.get("Items", [])
    except ClientError:
        logger.exception("Failed to query access summary.")
        return {
            "ok": False,
            "message": "Failed to query access summary",
            "items": [],
            "total": 0,
        }

    result_items = []
    total = 0

    for item in items:
        access_count = int(item.get("access_count", 0))
        total += access_count
        result_items.append(
            {
                "date": item["SK"].replace("DATE#", ""),
                "accessCount": access_count,
                "lastAccessedAt": item.get("last_accessed_at"),
            }
        )

    return {
        "ok": True,
        "short_code": short_code,
        "startDate": start_date,
        "endDate": end_date,
        "total": total,
        "items": result_items,
    }


# スタート地点
# redirect Lambda から呼ばれる場合も、
# API Gateway から直接呼ばれる場合も、
# AWS はまずこの関数を実行する
def lambda_handler(event, context):
    # 受け取った event を CloudWatch Logs に出す
    logger.info("event=%s", json.dumps(event, ensure_ascii=False, default=str))

    # 1. redirect Lambda からの非同期呼び出し
    # redirect 側で source="redirect.lambda" を入れているので、
    # それを見てアクセス記録処理に進む
    if event.get("source") == "redirect.lambda":
        result = record_access(event)
        return result

    # 2. API Gateway 経由の場合は HTTP メソッドを判定
    http_method = get_http_method(event)

    # POST /analytics
    # body の内容をもとにアクセス記録を保存する
    if http_method == "POST":
        payload = parse_body(event)
        result = record_access(payload)

        if result.get("ok"):
            return json_response(200, result)
        return json_response(400, result)

    # GET /analytics?shortCode=abc123&startDate=2026-04-01&endDate=2026-04-09
    # 指定期間の日別アクセス集計を返す
    if http_method == "GET":
        short_code = get_query_param(event, "shortCode") or get_path_param(event, "shortCode")
        if not short_code:
            return json_response(400, {"message": "shortCode is required"})

        # startDate / endDate が未指定なら直近7日分を返す
        today = datetime.now(timezone.utc).date()
        default_start = (today - timedelta(days=6)).isoformat()
        default_end = today.isoformat()

        start_date = get_query_param(event, "startDate") or default_start
        end_date = get_query_param(event, "endDate") or default_end

        result = list_access_summary(short_code, start_date, end_date)
        if result.get("ok"):
            return json_response(200, result)
        return json_response(500, result)

    # GET / POST 以外は許可しない
    return json_response(405, {"message": "Method Not Allowed"})