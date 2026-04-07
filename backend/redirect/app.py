# このコードは、公開プロフィール画面でリンクが押されたときに、
# 外部サイトへリダイレクトするための Lambda 関数です。
#
# 将来的には frontend/profile.html などのリンクから呼ばれる想定です。
# 例:
# <a href="/r/inukai/youtube">YouTube</a>
#
# 入力は API Gateway から渡される pathParameters を想定しています。
# 例:
# {
#   "pathParameters": {
#     "creatorId": "inukai",
#     "linkId": "youtube"
#   }
# }
#
# 戻り値の条件は以下です。
# - 400: creatorId または linkId がない
# - 404: creatorId / linkId に対応するリンクが見つからない
# - 302: 対応するリンクが見つかったので外部URLへリダイレクトする
# - 500: 想定外のサーバーエラー
#
# 今は DynamoDB の代わりに、Python の辞書 LINKS を仮データとして使っています。
# 本番では LINKS の部分を DynamoDB 参照に置き換える想定です。
#
# このファイルを python3 app.py で直接実行すると、
# 一番下の test_event を使ってローカル確認できます。

import json
from typing import Any, Dict, Optional


# 仮のリンク定義
# 後で DynamoDB 参照に置き換える想定
LINKS: Dict[str, Dict[str, str]] = {
    "inukai": {
        "instagram": "https://www.instagram.com/",
        "x": "https://x.com/",
        "youtube": "https://www.youtube.com/",
        "shop": "https://example.com/shop",
    }
}


def build_response(
    status_code: int,
    body: Dict[str, Any],
    headers: Optional[Dict[str, str]] = None,
) -> Dict[str, Any]:
    """
    API Gateway に返すための JSON レスポンスを作る共通関数です。

    例:
    - 400 入力不足
    - 404 データなし
    - 500 サーバーエラー
    """
    base_headers = {
        "Content-Type": "application/json; charset=utf-8",
    }
    if headers:
        base_headers.update(headers)

    return {
        "statusCode": status_code,
        "headers": base_headers,
        "body": json.dumps(body, ensure_ascii=False),
    }


def build_redirect_response(location: str) -> Dict[str, Any]:
    """
    外部URLへリダイレクトするためのレスポンスを作る関数です。

    302 と Location ヘッダーを返すことで、
    ブラウザに「別のURLへ移動してください」と伝えます。
    """
    return {
        "statusCode": 302,
        "headers": {
            "Location": location,
            "Cache-Control": "no-store",
        },
        "body": "",
    }


def get_redirect_url(creator_id: str, link_id: str) -> Optional[str]:
    """
    creator_id と link_id を受け取って、
    対応する外部URLを LINKS から探す関数です。

    戻り値:
    - URL が見つかれば文字列を返す
    - 見つからなければ None を返す
    """
    creator_links = LINKS.get(creator_id)
    if not creator_links:
        return None

    return creator_links.get(link_id)


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda の本体です。

    想定ルート:
      GET /r/{creatorId}/{linkId}

    想定イベント:
    {
      "pathParameters": {
        "creatorId": "inukai",
        "linkId": "youtube"
      }
    }
    """
    try:
        # 1. pathParameters を受け取る
        path_parameters = event.get("pathParameters") or {}

        # 2. creatorId と linkId を取り出す
        creator_id = path_parameters.get("creatorId")
        link_id = path_parameters.get("linkId")

        # 3. creatorId または linkId がなければ 400 を返す
        if not creator_id or not link_id:
            return build_response(
                400,
                {
                    "message": "creatorId と linkId が必要です。"
                },
            )

        # 4. creatorId と linkId に対応する URL を探す
        redirect_url = get_redirect_url(creator_id, link_id)

        # 5. URL が見つからなければ 404 を返す
        if not redirect_url:
            return build_response(
                404,
                {
                    "message": "対象リンクが見つかりませんでした。",
                    "creatorId": creator_id,
                    "linkId": link_id,
                },
            )

        # 6. 本来はここでクリック数を記録する
        # 例:
        # save_click_event(creator_id, link_id)

        # 7. URL が見つかったので 302 で外部サイトへリダイレクトする
        return build_redirect_response(redirect_url)

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
        "pathParameters": {
            "creatorId": "inukai",
            # 302 の確認
            "linkId": "youtube",
            # 404 の確認をしたいときは上をコメントアウトして下を使う
            # "linkId": "unknown",
        }
    }

    # 400 の確認をしたいときは creatorId または linkId を消す
    # test_event = {
    #     "pathParameters": {
    #         "creatorId": "inukai"
    #     }
    # }

    result = lambda_handler(test_event, None)
    print(json.dumps(result, ensure_ascii=False, indent=2))

    # python3 app.py を実行すると、ローカルで Lambda 関数の動作を確認できます。
    # 返ってくる結果は JSON 形式で表示されます。