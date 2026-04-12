# Creator Route Service Portfolio

個人クリエイター向け BtoC 導線サービスを題材にした、  
AWS / SRE / 監視 / IaC / CI/CD 寄りのポートフォリオです。

## 目的
- AWS インフラ設計の見せ場を作る
- Terraform による IaC を見せる
- GitHub Actions による CI を入れる
- 将来的に CloudWatch / 運用改善 / 監視設計へ広げる

## プロジェクト概要
個人クリエイターが、自分の SNS や販売先リンクを 1 ページにまとめて公開できるサービスを想定したポートフォリオです。  
Phase 1 では、短縮コードを使ったリダイレクト機能とアクセス記録機能を、AWS のサーバレス構成で実装しています。

今回の実装では、以下の流れを構築しました。

- API Gateway で `/r/{shortCode}` を受け付ける
- redirect Lambda が `shortCode` に対応する遷移先 URL を `link_master` から取得する
- `302` リダイレクトで遷移させる
- analytics Lambda がアクセス情報を `access-summary` に記録する
- DynamoDB で `access_count` を増加させる

## Phase 1
- S3
- CloudFront
- API Gateway
- Lambda
- DynamoDB
- CloudWatch
- Terraform
- GitHub Actions

## Phase 2
- ALB
- Zabbix
- 監視設計の拡張
- 通知設計
- 運用改善

## 現在の実装範囲
現在は Phase 1 の一部として、以下を実装済みです。

- Terraform による AWS リソース作成
- redirect Lambda の作成
- analytics Lambda の作成
- DynamoDB `link_master` テーブル作成
- DynamoDB `access-summary` テーブル作成
- API Gateway の作成
- `GET /r/{shortCode}` ルート作成
- API Gateway → Lambda → DynamoDB の動作確認
- アクセス記録の加算確認

## AWS構成
- API Gateway
- Lambda
  - redirect Lambda
  - analytics Lambda
- DynamoDB
  - `link_master`
  - `access-summary`
  - `creators-links`（今後利用想定）
- IAM
- CloudWatch Logs
- S3
- Terraform
- GitHub Actions

## 処理の流れ
1. ユーザーが API Gateway の `/r/{shortCode}` にアクセス
2. redirect Lambda が起動
3. DynamoDB `link_master` から `shortCode` に対応する `target_url` を取得
4. redirect Lambda が `302` レスポンスを返し、遷移先へリダイレクト
5. redirect Lambda が analytics Lambda を呼び出す
6. analytics Lambda が `access-summary` にアクセス記録を書き込む
7. `access_count` が加算される

## 動作確認結果
以下の動作確認を実施しました。

- `terraform apply` により AWS リソース作成を確認
- `link_master` にテストデータ投入を確認
- redirect Lambda 単体テスト成功
- analytics Lambda 単体テスト成功
- API Gateway 経由で `https://example.com` へのリダイレクト成功
- `access-summary` の `access_count` 増加を確認

## 使用技術
- Terraform
- AWS Lambda (Python)
- Amazon API Gateway
- Amazon DynamoDB
- Amazon CloudWatch Logs
- IAM
- S3
- GitHub Actions
- Git / GitHub

## ディレクトリ構成
```text
terraform-portfolio/
├─ terraform/
│  ├─ provider.tf             # AWS Provider 設定
│  ├─ versions.tf             # Terraform / Provider バージョン定義
│  ├─ variables.tf            # 入力変数
│  ├─ outputs.tf              # 出力値
│  ├─ main.tf                 # 共通定義
│  ├─ lambda.tf               # Lambda 関連
│  ├─ dynamodb.tf             # DynamoDB 関連
│  ├─ iam.tf                  # IAM 関連
│  ├─ s3.tf                   # S3 関連
│  └─ apigateway.tf           # API Gateway 関連
├─ backend/
│  ├─ redirect/
│  │  └─ app.py               # redirect Lambda
│  └─ analytics/
│     └─ app.py               # analytics Lambda
├─ frontend/                  # フロント側実装
├─ .github/
│  └─ workflows/
│     └─ terraform-ci.yml     # Terraform CI (fmt / validate / plan)
├─ README.md
└─ .gitignore