# 流れ
# リクエストから shortCode を取る
# DynamoDB でリンクを探す
# 必要なら analytics Lambda を呼ぶ
# 302 で外部URLへ飛ばす


# API Gateway や Lambda が扱いやすい JSON形式 に変換
import json
# ログを出力
import logging
# 環境変数を読むため
import os
# 現在時刻をUTCで作るため 
from datetime import datetime, timezone
# AWSをPythonから操作するための公式SDK
import boto3
# AWSアクセス時のエラーを 捕まえるため
from botocore.exceptions import ClientError
# loggerオブジェクトを作る
logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
lambda_client = boto3.client("lambda")
# lambdaの環境変数に入力する　キー　LINK_TABLE_NAME　値　link_master　（DynamoDB テーブル名）
LINK_TABLE_NAME = os.environ["LINK_TABLE_NAME"]
# lambdaの環境変数に入力する　キー　ANALYTICS_FUNCTION_NAME　値 analytics-lambda
ANALYTICS_FUNCTION_NAME = os.environ.get("ANALYTICS_FUNCTION_NAME", "")

link_table = dynamodb.Table(LINK_TABLE_NAME)


# JSON形式のレスポンスを返す共通関数で400,404,500の値のメッセージを返す際しよう

def json_response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json; charset=utf-8",
        },
        "body": json.dumps(body, ensure_ascii=False),
    }

# リダイレクト専用のレスポンスを返します。
def redirect_response(location: str) -> dict:
    return {
        "statusCode": 302,
        "headers": {
            "Location": location,
            "Cache-Control": "no-store",
        },
        "body": "",
    }
# リクエストの中から shortCode を取り出す関数です。
# pathParameters["shortCode"]
# queryStringParameters["shortCode"]
# rawPath の最後
# 見つかれば shortCode
# なければ None

def get_short_code(event: dict) -> str | None:
    path_params = event.get("pathParameters") or {}
    if path_params.get("shortCode"):
        return path_params["shortCode"]

    query_params = event.get("queryStringParameters") or {}
    if query_params.get("shortCode"):
        return query_params["shortCode"]

    raw_path = event.get("rawPath", "")
    if raw_path:
        parts = [p for p in raw_path.split("/") if p]
        if parts:
            return parts[-1]

    return None
# リクエストヘッダーを安全に取る関数
# analytics に送るときに使用
def get_header(event: dict, name: str) -> str | None:
    headers = event.get("headers") or {}
    return headers.get(name) or headers.get(name.lower()) or headers.get(name.title())

# アクセス元IPを取り出す関数
# API Gateway の event に入っている
# requestContext["http"]["sourceIp"]
# requestContext["identity"]["sourceIp"]
# analytics に渡す。
def get_source_ip(event: dict) -> str | None:
    request_context = event.get("requestContext") or {}

    http_info = request_context.get("http") or {}
    if http_info.get("sourceIp"):
        return http_info["sourceIp"]

    identity = request_context.get("identity") or {}
    if identity.get("sourceIp"):
        return identity["sourceIp"]

    return None
# analytics Lambda を非同期で呼ぶ関数です。

def invoke_analytics_async(item: dict, event: dict, short_code: str) -> None:
    if not ANALYTICS_FUNCTION_NAME:
        logger.info("ANALYTICS_FUNCTION_NAME is not set. Skip analytics invoke.")
        return
# analytics Lambda に渡すデータを作っている
# どの shortCode か
# creator_id
# link_id
# いつアクセスされたか
# user-agent
# referer
# source IP
    payload = {
        "source": "redirect.lambda",
        "short_code": short_code,
        "creator_id": item.get("creator_id"),
        "link_id": item.get("link_id"),
        "accessed_at": datetime.now(timezone.utc).isoformat(),
        "user_agent": get_header(event, "User-Agent"),
        "referer": get_header(event, "Referer"),
        "source_ip": get_source_ip(event),
    }
 # analytics Lambda を呼び出す処理
 # 呼び出す先の Lambda 関数名
 # 環境変数 ANALYTICS_FUNCTION_NAME に入っている値を使う
  # analytics Lambda に渡すデータ
 # payload は Python の dict なので、
 # JSON文字列に変換してから bytes にして渡す
    try:
        lambda_client.invoke(
            FunctionName=ANALYTICS_FUNCTION_NAME,
            InvocationType="Event",  # 非同期
            Payload=json.dumps(payload).encode("utf-8"),
        )
    except Exception:
        logger.exception("Failed to invoke analytics lambda. short_code=%s", short_code)

# スタート地点　API Gateway からリクエストが来ると、AWS がこの関数を呼びます
def lambda_handler(event, context):
    # CloudWatch Logsにログを出すため
    logger.info("event=%s", json.dumps(event, ensure_ascii=False))
  # リクエストの中から short_code を取り出す
    short_code = get_short_code(event)
 # short_code が取れなかったら入力不足なので 400 を返す
    if not short_code:
        return json_response(400, {"message": "shortCode is required"})

    try:
        # 前提:
        # link_master テーブルは partition key = short_code
          # DynamoDB の link_master テーブルから
        # short_code をキーにして 1件取得する
        response = link_table.get_item(
            Key={"short_code": short_code}
        )
            # 取得結果の中から Item を取り出す
        # 見つからなければ item は None になる
        item = response.get("Item")
    # DynamoDB 読み取りで問題が起きた時に、
    except ClientError:
        logger.exception("Failed to get link item from DynamoDB.")
        return json_response(500, {"message": "Failed to read link data"})
  # 該当データがなければ 404
#   CloudWatch やAPIレスポンスで何が見つからなかったかわかりやすくするために、short_code も返す
    if not item:
        logger.warning("Link not found for short_code=%s", short_code)
        return json_response(404,        
         {
            "message": "Link not found",
            "short_code": short_code
            })
      # リンクはあるが無効化されている場合は 403
    if not item.get("is_active", True):
        logger.info("Link is inactive for short_code=%s", short_code)
        return json_response(403, 
        {"message": "Link is inactive" , "short_code": short_code})
   
   #「システムエラー」と見るより、リンク先データ不足
   # 遷移先URLを取得
    target_url = item.get("target_url")
    if not target_url:
        logger.warning("target_url is missing for short_code=%s", short_code)        
  # データはあるが URL が入っていなければ 404
        return json_response(
            404, {
                "message": "target_url is missing",
                "short_code": short_code})
 # analytics Lambda を非同期で呼ぶ
    # アクセス記録用 Lambda を呼ぶ
    invoke_analytics_async(item, event, short_code)
    # 正常にどこへ飛ばしたかを CloudWatch Logs に残す
    logger.info("Redirecting to %s for short_code=%s", target_url, short_code)
    
  # 最後に 302 リダイレクトを返す
    # ブラウザは target_url に移動する
    return redirect_response(target_url)