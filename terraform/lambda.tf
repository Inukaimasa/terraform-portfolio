# 前提。

# backend/redirect/app.py
# backend/analytics/app.py
# Python ハンドラは def lambda_handler(event, context):
# iam.tf に 実行ロールがすでにある
# aws_iam_role.redirect_lambda_exec
# aws_iam_role.analytics_lambda_exec


# lambda.tf や iam.tf参照しているものは、参照した名前と同じ resource が必要です。
#  local.name_prefix
#  aws_iam_role.redirect_lambda_exec
#  aws_iam_role.analytics_lambda_exec
#  aws_dynamodb_table.link_master
#  aws_dynamodb_table.access_summary

# 下記コマンドを使用して検索をする
# grep -R 'name_prefix' terraform
# grep -R 'redirect_lambda_exec' terraform
# grep -R 'analytics_lambda_exec' terraform
# grep -R 'link_master' terraform
# grep -R 'access_summary' terraform

# 1. Lambdaの中身を zip 化
# backend/redirect,backend/analyticsを zip にして、Lambda に渡せる形にします。

# 関数名.実行ロール,runtime (python3.13),handler (app.lambda_handler),timeout.memory_size.環境変数

# redirect と analytics の Lambda 関数を作って、コード・ロール・環境変数・ログ設定をひもづけるファイルです。

############################################
# Lambda package (zip)
############################################
# data は「何かを読む・生成するための定義」です
# ここでは Lambdaコードをzip化するための準備 をしています
# "redirect_lambda_zip" は Terraform 内での名前です

# type "zip" は zip 化することを指定しています  
# backend/redirect/ の中身が zip 化されて、output_path で指定した場所に保存されます。
# path.module は「いまの Terraform モジュールの場所」
# つまり terraform/build/redirect.zip みたいな場所に zip ができます


############################################
# Lambda package (zip)
############################################

data "archive_file" "redirect_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/redirect"
  output_path = "${path.module}/redirect_lambda.zip"
}

data "archive_file" "analytics_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/analytics"
  output_path = "${path.module}/analytics_lambda.zip"
}

data "archive_file" "analytics_read_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/analytics_read"
  output_path = "${path.module}/analytics_read_lambda.zip"
}

############################################
# CloudWatch Logs
############################################

# redirect
#checkov:skip=CKV_AWS_338:One-year log retention is deferred for this non-production portfolio environment.
#checkov:skip=CKV_AWS_158:Customer-managed KMS for CloudWatch Logs is deferred for this non-production portfolio environment.
resource "aws_cloudwatch_log_group" "redirect" {
  name              = "/aws/lambda/${local.name_prefix}-redirect"
  retention_in_days = 7

  tags = {
    Name = "${local.name_prefix}-redirect-log"
  }
}

# analytics
#checkov:skip=CKV_AWS_338:One-year log retention is deferred for this non-production portfolio environment.
#checkov:skip=CKV_AWS_158:Customer-managed KMS for CloudWatch Logs is deferred for this non-production portfolio environment.
resource "aws_cloudwatch_log_group" "analytics" {
  name              = "/aws/lambda/${local.name_prefix}-analytics"
  retention_in_days = 7

  tags = {
    Name = "${local.name_prefix}-analytics-log"
  }
}

# analytics_read
#checkov:skip=CKV_AWS_338:One-year log retention is deferred for this non-production portfolio environment.
#checkov:skip=CKV_AWS_158:Customer-managed KMS for CloudWatch Logs is deferred for this non-production portfolio environment.
resource "aws_cloudwatch_log_group" "analytics_read" {
  name              = "/aws/lambda/${local.name_prefix}-analytics-read"
  retention_in_days = 7

  tags = {
    Name = "${local.name_prefix}-analytics-read-log"
  }
}

############################################
# Lambda functions analytics
############################################
#checkov:skip=CKV_AWS_115:Reserved concurrency is deferred because this portfolio has low traffic and no downstream resource requiring concurrency protection yet.
#checkov:skip=CKV_AWS_117:This Lambda intentionally runs outside a VPC because it only uses managed AWS services.
#checkov:skip=CKV_AWS_173:Customer-managed KMS for Lambda environment variables is deferred for this non-production portfolio environment.
#checkov:skip=CKV_AWS_272:Code signing is deferred because this portfolio currently uses a simple non-production deployment flow.
#checkov:skip=CKV_AWS_116:DLQ is deferred for this function until asynchronous failure handling is implemented.
#checkov:skip=CKV_AWS_50:X-Ray tracing is deferred because CloudWatch Logs are sufficient for debugging in this non-production portfolio environment.
resource "aws_lambda_function" "analytics" {
  function_name = "${local.name_prefix}-analytics"
  role          = aws_iam_role.lambda_exec_role.arn

  filename         = data.archive_file.analytics_lambda_zip.output_path
  source_code_hash = data.archive_file.analytics_lambda_zip.output_base64sha256

  runtime     = "python3.13"
  handler     = "app.lambda_handler"
  timeout     = 10
  memory_size = 128

  environment {
    variables = {
      ACCESS_SUMMARY_TABLE_NAME = aws_dynamodb_table.access_summary.name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.analytics
  ]

  tags = {
    Name = "${local.name_prefix}-analytics"
  }
}

############################################
# Lambda functions analytics_read
############################################
#checkov:skip=CKV_AWS_115:Reserved concurrency is deferred because this portfolio has low traffic and no downstream resource requiring concurrency protection yet.
#checkov:skip=CKV_AWS_117:This Lambda intentionally runs outside a VPC because it only uses managed AWS services.
#checkov:skip=CKV_AWS_173:Customer-managed KMS for Lambda environment variables is deferred for this non-production portfolio environment.
#checkov:skip=CKV_AWS_272:Code signing is deferred because this portfolio currently uses a simple non-production deployment flow.
#checkov:skip=CKV_AWS_116:DLQ is deferred for this function because it is not used for asynchronous failure handling in the current portfolio scope.
#checkov:skip=CKV_AWS_50:X-Ray tracing is deferred because CloudWatch Logs are sufficient for debugging in this non-production portfolio environment.
resource "aws_lambda_function" "analytics_read" {
  function_name = "${local.name_prefix}-analytics-read"
  role          = aws_iam_role.lambda_exec_role.arn

  filename         = data.archive_file.analytics_read_lambda_zip.output_path
  source_code_hash = data.archive_file.analytics_read_lambda_zip.output_base64sha256

  runtime     = "python3.13"
  handler     = "app.lambda_handler"
  timeout     = 10
  memory_size = 128

  environment {
    variables = {
      ACCESS_SUMMARY_TABLE_NAME = aws_dynamodb_table.access_summary.name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.analytics_read
  ]

  tags = {
    Name = "${local.name_prefix}-analytics-read"
  }
}

############################################
# Lambda functions redirect
############################################
#checkov:skip=CKV_AWS_116:DLQ is deferred for this function because it is not used for asynchronous failure handling in the current portfolio scope.
#checkov:skip=CKV_AWS_272:Code signing is deferred because this portfolio currently uses a simple non-production deployment flow.
#checkov:skip=CKV_AWS_117:This Lambda intentionally runs outside a VPC because it only uses managed AWS services.
#checkov:skip=CKV_AWS_173:Customer-managed KMS for Lambda environment variables is deferred for this non-production portfolio environment.
#checkov:skip=CKV_AWS_50:X-Ray tracing is deferred because CloudWatch Logs are sufficient for debugging in this non-production portfolio environment.
resource "aws_lambda_function" "redirect" {
  function_name = "${local.name_prefix}-redirect"
  role          = aws_iam_role.lambda_exec_role.arn

  filename         = data.archive_file.redirect_lambda_zip.output_path
  source_code_hash = data.archive_file.redirect_lambda_zip.output_base64sha256

  runtime     = "python3.13"
  handler     = "app.lambda_handler"
  timeout     = 10
  memory_size = 128

  environment {
    variables = {
      LINK_TABLE_NAME         = aws_dynamodb_table.link_master.name
      ANALYTICS_FUNCTION_NAME = aws_lambda_function.analytics.function_name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.redirect
  ]

  tags = {
    Name = "${local.name_prefix}-redirect"
  }
}

############################################
# Lambda package (zip) config_alert
############################################
data "archive_file" "config_alert_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/config_alert"
  output_path = "${path.module}/config_alert_lambda.zip"
}

############################################
# CloudWatch Logs config_alert
############################################
#checkov:skip=CKV_AWS_338:One-year log retention is deferred for this non-production portfolio environment.
#checkov:skip=CKV_AWS_158:Customer-managed KMS for CloudWatch Logs is deferred for this non-production portfolio environment.
resource "aws_cloudwatch_log_group" "config_alert" {
  name              = "/aws/lambda/${local.name_prefix}-config-alert"
  retention_in_days = 7

  tags = {
    Name = "${local.name_prefix}-config-alert-log"
  }
}
############################################
# Lambda functions config_alert
############################################
#checkov:skip=CKV_AWS_115:Reserved concurrency is deferred because this portfolio has low traffic and no downstream resource requiring concurrency protection yet.
#checkov:skip=CKV_AWS_117:This Lambda intentionally runs outside a VPC because it only uses managed AWS services.
#checkov:skip=CKV_AWS_173:Customer-managed KMS for Lambda environment variables is deferred for this non-production portfolio environment.
#checkov:skip=CKV_AWS_272:Code signing is deferred because this portfolio currently uses a simple non-production deployment flow.
#checkov:skip=CKV_AWS_116:DLQ is deferred for this function because it is not used for asynchronous failure handling in the current portfolio scope.
#checkov:skip=CKV_AWS_50:X-Ray tracing is deferred because CloudWatch Logs are sufficient for debugging in this non-production portfolio environment.
resource "aws_lambda_function" "config_alert" {
  function_name = "${local.name_prefix}-config-alert"
  role          = aws_iam_role.lambda_exec_role.arn

  filename         = data.archive_file.config_alert_lambda_zip.output_path
  source_code_hash = data.archive_file.config_alert_lambda_zip.output_base64sha256

  runtime     = "python3.13"
  handler     = "app.lambda_handler"
  timeout     = 30
  memory_size = 128

  environment {
    variables = {
      # 環境変数があればここに追加
      ANTHROPIC_API_KEY = var.anthropic_api_key
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.config_alert
  ]

  tags = {
    Name = "${local.name_prefix}-config-alert"
  }
}
############################################
# SNS Topic（Config → Lambda のトリガー）
############################################
resource "aws_sns_topic" "config_alert" {
  name = "${local.name_prefix}-config-alerts"

  tags = {
    Name = "${local.name_prefix}-config-alerts"
  }
}
# SNS → Lambda の紐づけ
resource "aws_sns_topic_subscription" "config_alert_lambda" {
  topic_arn = aws_sns_topic.config_alert.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.config_alert.arn
}
  # Lambda 関数へのアクセス許可を追加
resource "aws_lambda_permission" "allow_invoke_config_alert"{
   statement_id  = "AllowSNSInvoke"
   action        = "lambda:InvokeFunction"
   function_name = aws_lambda_function.config_alert.function_name
   principal     = "sns.amazonaws.com"
   source_arn    = aws_sns_topic.config_alert.arn
 }
