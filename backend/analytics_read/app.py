# shortCode の全日分を合計して返す　lambda 間数

import json
import os
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Key

# DynamoDB リソースを作成
dynamodb = boto3.resource("dynamodb")

# 環境変数からテーブル名を取得
TABLE_NAME = os.environ["ACCESS_SUMMARY_TABLE_NAME"]

# 対象テーブル
table = dynamodb.Table(TABLE_NAME)


def decimal_to_int(value):
    """
    DynamoDB から返る数値は Decimal 型になることがあるため、
    JSON で扱いやすい int に変換する。
    """
    if isinstance(value, Decimal):
        return int(value)
    return value


def build_response(status_code: int, body: dict):
    """
    API Gateway に返すレスポンスを作る。
    CORS ヘッダもここで付与する。
    """
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "*",
            "Access-Control-Allow-Methods": "GET,OPTIONS"
        },
        "body": json.dumps(body, ensure_ascii=False)
    }


def lambda_handler(event, context):
   
    # GET /analytics/{shortCode} を受けて、
    # access-summary テーブルから対象 shortCode の集計結果を返す。
   
    try:
        # API Gateway の pathParameters から shortCode を取得
        path_parameters = event.get("pathParameters") or {}
        short_code = path_parameters.get("shortCode")

        # shortCode がない場合は 400
        if not short_code:
            return build_response(
                400,
                {
                    "message": "shortCode is required"
                }
            )

        # access-summary テーブルの PK は LINK#<shortCode> という前提
        pk = f"LINK#{short_code}"

        # PK をキーに Query 実行
        response = table.query(
            KeyConditionExpression=Key("PK").eq(pk)
        )

        items = response.get("Items", [])

        # データが存在しない場合は 404
        if not items:
            return build_response(
                404,
                {
                    "message": "analytics data not found",
                    "short_code": short_code
                }
            )

        # 同じ shortCode の全レコードを合計する
        total_access_count = 0
        latest_last_accessed_at = None

        for item in items:
            access_count = decimal_to_int(item.get("access_count", 0))
            total_access_count += access_count

            last_accessed_at = item.get("last_accessed_at")
            if last_accessed_at:
                if latest_last_accessed_at is None or last_accessed_at > latest_last_accessed_at:
                    latest_last_accessed_at = last_accessed_at

        # 正常時レスポンス
        return build_response(
            200,
            {
                "short_code": short_code,
                "access_count": total_access_count,
                "last_accessed_at": latest_last_accessed_at
            }
        )

    except Exception as e:
        # 想定外エラー時は 500
        return build_response(
            500,
            {
                "message": "internal server error",
                "error": str(e)
            }
        )