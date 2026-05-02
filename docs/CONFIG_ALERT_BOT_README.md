# 🤖 AWS Config × Claude 分析Bot

> AWSセキュリティアラートをClaude AIが日本語で自動分析し、Slackに通知するBot

---

## 📌 概要

AWS Configがセキュリティルール違反を検知したとき、Claude APIが自動的に分析して「何が問題か・リスクレベル・対応手順」を日本語でSlackに通知します。

```
AWS Config ルール違反を検知
　↓
EventBridge → SNS → Lambda
　↓
Claude APIで日本語分析
　↓
Slackに通知
```

---

## 🏗️ アーキテクチャ

```
┌─────────────────────────────────────────────────┐
│  AWS                                            │
│                                                 │
│  AWS Config                                     │
│     │ ルール違反を検知                           │
│     ↓                                           │
│  SNS Topic（config-alerts）                     │
│     │                                           │
│     ↓                                           │
│  Lambda（my-portfolio-dev-config-alert）        │
│     │ Python 3.13                               │
│     │ ① アラート内容を受け取る                  │
│     │ ② Claude APIに分析依頼                   │
│     │ ③ 分析結果をSlackに送る                  │
│     ↓                                           │
└─────────────────────────────────────────────────┘
         ↓
   Slack #general
   🚨 AWS Config アラート
   ルール: restricted-ssh
   Claude分析結果：...
```

---

## 📂 ディレクトリ構成

```
terraform-portfolio/
├── backend/
│   └── config_alert/
│       └── app.py          # Lambda本体（Claude API連携）
├── terraform/
│   ├── lambda.tf           # Lambdaリソース・SNS定義
│   └── variables.tf        # 変数定義
└── docs/
    └── setup-checklist.html # 構築手順チェックリスト
```

---

## 🔧 Lambdaコードの処理フロー（app.py）

コードは5つのブロックで構成されています：

### ブロック① 環境変数の取得
```python
ANTHROPIC_API_KEY = os.environ["ANTHROPIC_API_KEY"]
SLACK_WEBHOOK_URL = os.environ["SLACK_WEBHOOK_URL"]
```
- AWSの環境変数からAPIキーを安全に取得
- コードに直書きしないことでセキュリティを担保

### ブロック② AWSアラートの受け取り
```python
message = json.loads(event['Records'][0]['Sns']['Message'])
rule_name     = message.get('configRuleName', '不明')
resource_type = message.get('resourceType', '不明')
resource_id   = message.get('resourceId', '不明')
compliance    = message.get('newEvaluationResult', {}).get('complianceType', '不明')
```
- SNS経由でLambdaに届くJSON形式のアラートを受け取る
- 仕様：[AWS Lambda with SNS](https://docs.aws.amazon.com/lambda/latest/dg/with-sns.html)

### ブロック③ Claudeへの質問文を作成
```python
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
```
- ②で取り出した変数をf文字列でプロンプトに埋め込む

### ブロック④ Claude APIを呼び出す
```python
payload = json.dumps({
    "model": "claude-haiku-4-5-20251001",
    "max_tokens": 1024,
    "messages": [{"role": "user", "content": prompt}]
}).encode()
```
- モデル：claude-haiku-4-5（コスト最適）
- ③のpromptをAPIに送り、分析結果（analysis）を受け取る

### ブロック⑤ Slackに通知する
```python
slack_payload = json.dumps({
    "text": f"🚨 *AWS Config アラート*\n*ルール:* {rule_name}\n*リソース:* {resource_id}\n\n*Claude分析結果:*\n{analysis}"
}).encode()
```
- ④のanalysisをSlack Webhook URLに送信

### 変数の受け渡し
```
① ANTHROPIC_API_KEY ──────────────────────→ ④で使う
① SLACK_WEBHOOK_URL ──────────────────────→ ⑤で使う
② rule_name / resource_id 等 ─────────────→ ③で使う
③ prompt ─────────────────────────────────→ ④で使う
④ analysis（分析結果）────────────────────→ ⑤で使う
```

---

## 🚨 検知するAWS Configルール

| ルール名 | 検知内容 | リスク |
|---|---|---|
| `restricted-ssh` | SGにPort22が全開放された | HIGH |
| `s3-bucket-public-read-prohibited` | S3がパブリックになった | HIGH |
| `cloudtrail-enabled` | CloudTrailが無効化された | HIGH |

---

## 💰 料金目安

| モデル | 1回あたり | 月100回 |
|---|---|---|
| claude-haiku-4-5 | 約0.2円 | 約20円 |
| claude-sonnet-4-6 | 約0.9円 | 約90円 |

> ポートフォリオ用途なら月200円以内で十分動きます

---

## 🛠️ セットアップ手順

詳細は `docs/setup-checklist.html` を参照。

### 必要なもの
- Claude Pro アカウント
- Anthropic APIキー（console.anthropic.com）
- Slack ワークスペース + Webhook URL
- AWSアカウント

### 環境変数（Lambda）

| 変数名 | 説明 |
|---|---|
| `ANTHROPIC_API_KEY` | Anthropic APIキー |
| `SLACK_WEBHOOK_URL` | Slack Incoming Webhook URL |

### GitHub Secrets

| Secret名 | 説明 |
|---|---|
| `ANTHROPIC_API_KEY` | Anthropic APIキー |
| `SLACK_WEBHOOK_URL` | Slack Webhook URL |

### デプロイ

```bash
cd terraform
terraform init -backend-config=backend.hcl
terraform apply \
  -var="anthropic_api_key=sk-ant-..." \
  -var="slack_webhook_url=https://hooks.slack.com/..."
```

---

## ✅ 動作確認

Lambdaのテストタブで以下のJSONを実行：

```json
{
  "Records": [
    {
      "Sns": {
        "Message": "{\"configRuleName\": \"restricted-ssh\", \"resourceType\": \"AWS::EC2::SecurityGroup\", \"resourceId\": \"sg-12345678\", \"newEvaluationResult\": {\"complianceType\": \"NON_COMPLIANT\"}}"
      }
    }
  ]
}
```

Slackに以下が届けば成功：

```
🚨 AWS Config アラート
ルール: restricted-ssh
リソース: sg-12345678

Claude分析結果:
1. セキュリティグループにSSH（Port22）が全開放されています
2. リスクレベル：HIGH
3. 対応手順：
   - SGのインバウンドルールを確認
   - 0.0.0.0/0を削除して特定IPに限定
   - SSMセッションマネージャーへ切り替えを検討
```

---

## 💡 面接でのアピールポイント

> 「AWS ConfigのセキュリティアラートをClaude APIで自動分析し、日本語で対応手順をSlackに通知する仕組みをTerraformで構築しました。インフラ監視とAI活用を組み合わせた実装経験があります。」

---

## 📅 作成日

2026年5月2日
