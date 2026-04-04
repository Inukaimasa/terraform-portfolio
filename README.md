# Creator Route Service Portfolio

個人クリエイター向け BtoC 導線サービスを題材にした、
AWS / SRE / 監視 / IaC / CI/CD 寄りのポートフォリオです。

## 目的
- AWS インフラ設計の見せ場を作る
- Terraform による IaC を見せる
- GitHub Actions による CI を入れる
- 将来的に CloudWatch / 運用改善 / 監視設計へ広げる

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

## ディレクトリ構成
```text
terraform/
  provider.tf             # AWS Provider 設定
  versions.tf             # Terraform / Provider バージョン定義
  main.tf                 # メインリソース定義
  variables.tf            # 入力変数
  outputs.tf              # 出力値

.github/
  workflows/
    terraform-ci.yml      # Terraform CI (fmt / validate / plan)