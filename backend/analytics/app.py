# 管理画面の「アクセス集計」画面に返すデータを作る Lambda 関数のコードです。
# 将来的には frontend/admin-analytics.html から API を呼び出して使う想定です。
#
# 今はまだ HTML と未接続なので、
# ファイルの一番下にある test_event を使ってローカル確認します。
#
# このコードの流れ
# 1. queryStringParameters を受け取る
# 2. creatorId を取り出す
# 3. period を取り出す
# 4. creatorId がなければ 400 を返す
# 5. データが見つからなければ 404 を返す
# 6. データが見つかれば 200 で JSON を返す
#
# 判定条件
# - 400: creatorId がない
# - 200: creatorId があり、対応する集計データもある
# - 404: creatorId はあるが、対応する集計データがない
#
# 返したいデータのイメージ
# {
#   "creatorId": "inukai",
#   "period": "7d",
#   "totalClicks": 58,
#   "byLink": [
#     { "linkId": "instagram", "linkName": "Instagram", "clickCount": 22 }
#   ],
#   "byDate": [
#     { "date": "2026-04-01", "clickCount": 5 }
#   ]
# }

import json
from typing import Any, Dict


# 仮の集計データ
# 後で DynamoDB から取得する想定です。
# 今はローカル確認のため、Python の辞書に直接書いています。
ANALYTICS_DATA: Dict[str, Dict[str, Any]] = {
    "inukai": {
        "7d": {
            "creatorId": "inukai",
            "period": "7d",
            "totalClicks": 58,
            "byLink": [
                {"linkId": "instagram", "linkName": "Instagram", "clickCount": 22},
                {"linkId": "x", "linkName": "X", "clickCount": 14},
                {"linkId": "youtube", "linkName": "YouTube", "clickCount": 12},
                {"linkId": "shop", "linkName": "作品販売ページ", "clickCount": 10},
            ],
            "byDate": [
                {"date": "2026-04-01", "clickCount": 5},
                {"date": "2026-04-02", "clickCount": 7},
                {"date": "2026-04-03", "clickCount": 9},
                {"date": "2026-04-04", "clickCount": 6},
                {"date": "2026-04-05", "clickCount": 12},
                {"date": "2026-04-06", "clickCount": 19},
            ],
        },
        "30d": {
            "creatorId": "inukai",
            "period": "30d",
            "totalClicks": 180,
            "byLink": [
                {"linkId": "instagram", "linkName": "Instagram", "clickCount": 70},
                {"linkId": "x", "linkName": "X", "clickCount": 45},
                {"linkId": "youtube", "linkName": "YouTube", "clickCount": 35},
                {"linkId": "shop", "linkName": "作品販売ページ", "clickCount": 30},
            ],
            "byDate": [
                {"date": "2026-03-08", "clickCount": 4},
                {"date": "2026-03-15", "clickCount": 8},
                {"date": "2026-03-22", "clickCount": 6},
                {"date": "2026-03-29", "clickCount": 10},
                {"date": "2026-04-05", "clickCount": 12},
                {"date": "2026-04-06", "clickCount": 19},
            ],
        },
    }
}


def build_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """
    API Gateway に返すための JSON レスポンスを作る共通関数です。

    例:
    - 200 成功
    - 400 入力不足
    - 404 データなし
    - 500 サーバーエラー
    """
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json; charset=utf-8",
        },
        "body": json.dumps(body, ensure_ascii=False),
    }


def get_analytics_data(creator_id: str, period: str) -> Dict[str, Any] | None:
    """
    creator_id と period を受け取って、
    該当する集計データを仮データから探す関数です。

    戻り値:
    - データが見つかれば辞書を返す
    - 見つからなければ None を返す
    """
    creator_data = ANALYTICS_DATA.get(creator_id)
    if not creator_data:
        return None

    return creator_data.get(period)


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda の本体です。

    想定ルート:
      GET /admin/analytics?creatorId=inukai&period=7d

    想定イベント:
    {
      "queryStringParameters": {
        "creatorId": "inukai",
        "period": "7d"
      }
    }
    """
    try:
        # 1. queryStringParameters を受け取る
        query_params = event.get("queryStringParameters") or {}

        # 2. creatorId を取り出す
        creator_id = query_params.get("creatorId")

        # 3. period を取り出す
        # period が指定されていない場合は "7d" をデフォルト値として使う
        period = query_params.get("period", "7d")

        # 4. creatorId がなければ 400 を返す
        if not creator_id:
            return build_response(
                400,
                {
                    "message": "creatorId が必要です。"
                },
            )

        # creatorId と period に対応する集計データを探す
        analytics = get_analytics_data(creator_id, period)

        # 5. データがなければ 404 を返す
        if not analytics:
            return build_response(
                404,
                {
                    "message": "対象の集計データが見つかりませんでした。",
                    "creatorId": creator_id,
                    "period": period,
                },
            )

        # 6. データがあれば 200 で返す
        return build_response(200, analytics)

    except Exception as e:
        # 想定外のエラーが起きた場合は 500 を返す
        return build_response(
            500,
            {
                "message": "サーバーエラーが発生しました。",
                "error": str(e),
            },
        )


if __name__ == "__main__":
    # ローカル確認用のテストデータです。
    # 本番では API Gateway から event が渡されます。

    test_event = {
        "queryStringParameters": {
            "creatorId": "inukai",
            # 200 の確認
            "period": "7d",
            # 404 の確認をしたいときは上をコメントアウトして下を使う
            # "period": "999d",
        }
    }

    # 400 の確認をしたいときは creatorId を消す
    # test_event = {
    #     "queryStringParameters": {
    #         "period": "7d"
    #     }
    # }

    result = lambda_handler(test_event, None)
    print(json.dumps(result, ensure_ascii=False, indent=2))

    # python3 app.py を実行すると、ローカルで Lambda 関数の動作を確認できます。
    # 返ってくる結果は JSON 形式で表示されます。