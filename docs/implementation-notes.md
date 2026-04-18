# Implementation Notes

## プロジェクト概要
個人クリエイター向け BtoC 導線サービスのポートフォリオ。

目的:
- AWS インフラ設計・構築
- SRE / 運用改善
- 監視設計
- IaC / Terraform
- CI/CD 設計
- サーバレス構成の実装

---

## 現在の構成イメージ
- Frontend: S3 + CloudFront
- API: API Gateway + Lambda
- DB: DynamoDB
- IaC: Terraform
- CI: GitHub Actions
- セキュリティ: WAF / CloudWatch Logs

---

## 画面一覧（最小構成）

### 公開側
1. トップページ
2. クリエイタープロフィール画面
3. リンク遷移用 URL (`/r/{shortCode}`)

### 管理側
4. ログイン画面
5. 管理トップ
6. プロフィール編集画面
7. リンク管理画面
8. アクセス確認画面

---

## API の考え方

### 公開用
- `GET /r/{shortCode}`
- `GET /public/creators/{creator_id}`
- `GET /public/creators/{creator_id}/links`

### 管理用
- `GET /admin/profile`
- `PUT /admin/profile`
- `GET /admin/links`
- `POST /admin/links`
- `PUT /admin/links/{link_id}`
- `DELETE /admin/links/{link_id}`
- `GET /admin/analytics`

---

## DB 設計の考え方

### 最小 3 テーブル案
1. `creators`
2. `creator_links`
3. `daily_stats`

### 別案（実装寄り）
1. `links`
2. `access_summary`

用途:
- リンク定義保持
- クリック集計
- 日別推移表示

---

## Terraform の実装順

### 基本順序
1. `dynamodb.tf`
2. `iam.tf`
3. `lambda.tf`
4. `apigateway.tf`
5. front と API 接続

理由:
- DynamoDB がデータの土台
- IAM が実行権限の土台
- Lambda がその上に乗る
- API Gateway が外部公開の入口

---

## Terraform ファイルの役割
- `variables.tf`: 入力値
- `provider.tf`: AWS provider 設定
- `versions.tf`: Terraform / provider バージョン
- `dynamodb.tf`: テーブル定義
- `iam.tf`: ロール / ポリシー
- `lambda.tf`: Lambda 本体
- `apigateway.tf`: ルート公開
- `outputs.tf`: 確認用出力

---

## Lambda 実装の考え方

### redirect
役割:
- shortCode から target_url を取得
- analytics Lambda を非同期呼び出し
- 302 リダイレクト

### analytics
役割:
- 集計情報を返す
- 管理画面表示用のJSONを返す

---

## 動作確認の基本

### redirect
- 正常: 302
- shortCode 不正: 404
- shortCode なし: 400
- DB エラー: 500

### analytics
- JSON で集計を返す
- 日別 / リンク別の数値確認

---

## API Gateway の考え方
同じサービス用途なので、HTTP API を 1つにまとめて route を追加する形が自然。

例:
- `GET /r/{shortCode}` → redirect Lambda
- `GET /analytics/{shortCode}` → analytics-read Lambda

---

## CloudFront / WAF メモ
- CloudFront URL: `https://da7nx3d6w85y9.cloudfront.net/profile.html`
- CloudFront 用 WAF は us-east-1
- CloudWatch Logs も us-east-1
- 実運用側 Web ACL: `CreatedByCloudFront-29a83738`
- 検証用 Web ACL: `portfolio-geo-count`

---

## CI / CD の考え方

### まず CI
- fmt
- init
- validate

### 次に手動で公開成功
- frontend/ を S3 に配置
- CloudFront で配信確認
- API と接続

### 最後に CD
- main push で deploy
- S3 sync
- CloudFront invalidation

---

## GitHub Actions 強化の方向
- OIDC で AWS 連携
- S3 配置
- CloudFront invalidation
- Security チェック追加
- Dependabot / Secret Protection 有効化

---

## 今後の改善候補
1. エラーハンドリング強化
2. CloudWatch メトリクス監視追加
3. GitHub Actions 強化
4. 障害対応観点の整理
5. S3 / CloudFront 公開改善
6. フロント見た目改善
7. 複数 shortCode 対応
8. creator_id / link_id の整理
9. Zabbix 監視設計への拡張

---

## ドキュメント運用方針
- `README.md`: 短い概要
- `docs/runbook-waf-cloudfront.md`: WAF / CloudFront 検証手順
- `docs/implementation-notes.md`: 実装メモ
- `docs/progress-log.md`: 作業履歴と次の一手
