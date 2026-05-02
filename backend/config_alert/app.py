"""
=============================================================
AWS Config → Claude分析Bot
=============================================================

【全体の流れ】

① 設定
   APIキー・Webhook URL（グローバル変数）
   ↓ ※①→②の直接受け渡しはなし（グローバルなのでどこでも使える）
② AWSアラートを受け取る
   ↓ rule_name / resource_id / compliance を渡す
③ Claudeへの質問文を作る
   ↓ prompt を渡す
④ Claude APIを呼ぶ
   ↓ analysis（分析結果テキスト）を渡す
⑤ Slackに通知する

【①から④・⑤への受け渡し】
  ANTHROPIC_API_KEY  → ④のheadersで使う
  SLACK_WEBHOOK_URL  → ⑤のURLで使う

=============================================================
"""

# =============================================================
# ① ライブラリ読み込み・設定
# =============================================================
# 【なぜimportするの？】
# 料理で言う「道具を棚から取り出す」作業
#
# json          → JSONデータ（AWSから届くデータ）を読み書きする
# urllib.request → インターネットにリクエストを送る（Claude API・Slack）
# os            → AWSの環境変数（APIキーなど）を読む
#
# 【os.environとは？】
# AWSのLambda設定画面に登録した秘密の値を取り出す仕組み
# コードに直書きすると危ないので外から読み込む
#
# 【グローバル変数】
# 関数の外で定義 → コード全体のどこからでも使える
# → ②には渡さないが④⑤から直接参照できる

import json
import urllib.request
import os

ANTHROPIC_API_KEY = os.environ["ANTHROPIC_API_KEY"]  # → ④のheadersで使う
SLACK_WEBHOOK_URL = os.environ["SLACK_WEBHOOK_URL"]   # → ⑤のURLで使う


# =============================================================
# ② AWSアラートを受け取る（lambda_handler）
# =============================================================
# 【def lambda_handlerとは？】
# AWSが「このLambdaを実行して」と呼ぶときに探す関数名
# 必ずこの名前にする決まり
#
# 【eventとは？】
# AWSが自動で渡してくるデータ（SNS経由だとこういう形で届く）
# {
#   "Records": [
#     {
#       "Sns": {
#         "Message": "{\"configRuleName\": \"restricted-ssh\", ...}"
#       }
#     }
#   ]
# }
# ※形式はAWSが決めた仕様（docs.aws.amazon.com/lambda/latest/dg/with-sns.html）
#
# 【なぜjson.loadsが必要？】
# Messageはただの「文字列」で届く → json.loadsで辞書型に変換して初めて使える
# 文字列: '{"configRuleName": "restricted-ssh"}'
# 変換後: {"configRuleName": "restricted-ssh"}  ← .getで取り出せる
#
# 【.get('キー名', 'デフォルト値')とは？】
# 辞書から値を取り出す。値がなかった時のデフォルト値を設定できる

def lambda_handler(event, context):

    message = json.loads(event['Records'][0]['Sns']['Message'])

    rule_name     = message.get('configRuleName', '不明')   # ↓③に渡す
    resource_type = message.get('resourceType', '不明')     # ↓③に渡す
    resource_id   = message.get('resourceId', '不明')       # ↓③に渡す
    compliance    = message.get('newEvaluationResult', {}).get('complianceType', '不明')  # ↓③に渡す


    # =============================================================
    # ③ Claudeへの質問文を作る（prompt）
    # =============================================================
    # 【f文字列とは？】
    # {}の中に変数を埋め込める書き方
    # 例: rule_name = "restricted-ssh"
    #     f"ルール名: {rule_name}" → "ルール名: restricted-ssh"
    #
    # 【②から受け取った変数をここで使う】
    # rule_name / resource_type / resource_id / compliance → {}に埋め込む
    #
    # 【promptは④に渡す】

    prompt = f"""
AWS Configが以下のセキュリティ違反を検知しました。
- ルール名: {rule_name}
- リソース種別: {resource_type}
- リソースID: {resource_id}
- コンプライアンス状態: {compliance}

以下を日本語で答えてください：
1. 何が問題か（1〜2行）
2. リスクレベル（HIGH/MEDIUM/LOW）
3. 対応手順（3ステップ以内）
"""


    # =============================================================
    # ④ Claude APIを呼ぶ
    # =============================================================
    # 【payloadとは？】
    # Claude APIに送るデータをJSON形式にまとめたもの
    #   model     → 使うClaudeのモデル
    #   max_tokens → 返答の最大文字数
    #   messages  → 会話の内容（③のpromptをここに入れる）
    #
    # 【headersとは？】
    # 「誰が・何の形式で送るか」をAPIに伝える情報
    #   x-api-key → ①のANTHROPIC_API_KEYをここで使う
    #
    # 【result['content'][0]['text']とは？】
    # Claudeのレスポンスはこういう形で返ってくる
    # {
    #   "content": [
    #     {
    #       "type": "text",
    #       "text": "1. SGにPort22が開放されています..."  ← これが欲しい
    #     }
    #   ]
    # }
    # → content[0]（最初の要素）のtextを取り出す
    #
    # 【analysisは⑤に渡す】

    payload = json.dumps({
        "model": "claude-haiku-4-5-20251001",
        "max_tokens": 1024,
        "messages": [{"role": "user", "content": prompt}]  # ③のpromptを使う
    }).encode()

    req = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=payload,
        headers={
            "x-api-key": ANTHROPIC_API_KEY,       # ①のグローバル変数を使う
            "anthropic-version": "2023-06-01",
            "content-type": "application/json"
        }
    )

    with urllib.request.urlopen(req) as res:
        result = json.loads(res.read())
        analysis = result['content'][0]['text']   # ↓⑤に渡す


    # =============================================================
    # ⑤ Slackに通知する
    # =============================================================
    # 【slack_payloadとは？】
    # Slackに送るメッセージをJSON形式にまとめたもの
    # textキーにメッセージ文字列を入れる
    #
    # 【④から受け取ったanalysisをここで使う】
    # 【①のSLACK_WEBHOOK_URLをここで使う】
    #
    # 【return {"statusCode": 200}とは？】
    # 「正常に完了しました」をAWSに返す決まり文句

    slack_payload = json.dumps({
        "text": (
            f"🚨 *AWS Config アラート*\n"
            f"*ルール:* {rule_name}\n"
            f"*リソース:* {resource_id}\n\n"
            f"*Claude分析結果:*\n{analysis}"   # ④のanalysisを使う
        )
    }).encode()

    slack_req = urllib.request.Request(
        SLACK_WEBHOOK_URL,                        # ①のグローバル変数を使う
        data=slack_payload,
        headers={"content-type": "application/json"}
    )
    urllib.request.urlopen(slack_req)

    return {"statusCode": 200}