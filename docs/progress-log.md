# Progress Log

## 現在地
ポートフォリオは、Terraform / Lambda / API Gateway / CloudFront / WAF を中心に、実装と検証を進めている段階。

---

## 進んだこと

### Terraform
- `archive provider` 追加
- `terraform init`
- `terraform fmt -recursive`
- `terraform validate`
- provider / resource 参照の整合確認

### IAM / DynamoDB / Lambda
- DynamoDB テーブル定義の整理
- IAM 実行ロールの理解
- Lambda 実行ロールと Terraform 実行権限の違いを整理
- redirect / analytics の役割整理

### API Gateway
- HTTP API に route を追加する方針を整理
- `GET /r/{shortCode}`
- `GET /analytics/{shortCode}`

### Frontend
- `python3 -m http.server 8000` でローカル起動
- CloudFront 配信の考え方整理
- profile.html の公開確認フロー整理

### CloudFront / WAF
- CloudFront 用 WAF は us-east-1 で管理することを理解
- CloudWatch Logs を us-east-1 に作成
- `aws-waf-logs-geo-test` を設定
- 実運用側 Web ACL が `CreatedByCloudFront-29a83738` であることを確認
- `portfolio-geo-count` は未関連付けと判明
- 自分のグローバルIPを使った IP set を作成
- 実運用側 Web ACL に Block ルールを追加
- CloudFront URL で **403** を確認

### 学び
- 403 は失敗ではなく、WAF が正しく効いた証拠
- 関連付いていない Web ACL を編集しても実トラフィックには効かない
- CloudFront 用 WAF は us-east-1 前提で考えると整理しやすい

---

## 直近の重要理解

### 今効いているもの
- `CreatedByCloudFront-29a83738`

### 今効いていないもの
- `portfolio-geo-count`

### 理由
`portfolio-geo-count` は関連リソースなし。今の Distribution に接続されていないため。

---

## 今日までの確認結果
- 自分のグローバルIP取得: 完了
- IP set 作成: 完了
- 実運用側 WAF への Block ルール追加: 完了
- CloudFront URL で 403 確認: 完了
- Logs / Sampled requests の土台作成: 完了

---

## 次にやること

### 優先1
- WAF のログと Sampled requests を読み、どのルールに一致したか確認

### 優先2
- Block ルールを外して再アクセスし、200 に戻ることを確認

### 優先3
- GeoMatch を Count で残すか整理

### 優先4
- 今回の手動設定を Terraform に落とし込む

### 優先5
- README を短くし、詳細は docs 配下へ分離

---

## Terraform 化するときの観点
- CloudFront 用 WAF は us-east-1
- IP set を Terraform で定義
- Web ACL を Terraform で定義
- CloudWatch Logs のロググループも定義
- IP はハードコードせず、変数または tfvars で管理

---

## README 運用方針
- README は短く保つ
- 概要 / 構成 / 強み / 今後の拡張を中心にする
- 詳細な作業ログや検証手順は docs に分ける

---

## 今後の docs 構成
- `docs/runbook-waf-cloudfront.md`
- `docs/implementation-notes.md`
- `docs/progress-log.md`

---

## 一言まとめ
今は「CloudFront に本当に効いている WAF を理解し、403 を確認できた」段階。
次は「証跡確認」と「Terraform 化」に進む。
