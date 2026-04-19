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
# analytics_read 用の Lambda ソースを zip 化
data "archive_file" "analytics_read_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/analytics_read"
  output_path = "${path.module}/analytics_read_lambda.zip"

}
############################################
# CloudWatch Logs
############################################


# redirect
#checkov:skip=CKV_AWS_158:Customer-managed KMS for CloudWatch Logs is deferred for this non-production portfolio environment.
#checkov:skip=CKV_AWS_338:One-year log retention is deferred for this non-production portfolio environment.
resource "aws_cloudwatch_log_group" "redirect" {
  name = "/aws/lambda/${local.name_prefix}-redirect"
  # 本番運用開始後は retention_in_days を設定して、ログの保存期間を365にする
  retention_in_days = 7
  #  etention_in_days = 365
  tags = {
    Name = "${local.name_prefix}-redirect-log"
  }
}

# analytics
#checkov:skip=CKV_AWS_338:One-year log retention is deferred for this non-production portfolio environment.
#checkov:skip=CKV_AWS_158:Customer-managed KMS for CloudWatch Logs is deferred for this non-production portfolio environment.


resource "aws_cloudwatch_log_group" "analytics" {
  name = "/aws/lambda/${local.name_prefix}-analytics"
  # 本番運用開始後は retention_in_days を設定して、ログの保存期間を365にする
  retention_in_days = 7
  #  etention_in_days = 365
  tags = {
    Name = "${local.name_prefix}-analytics-log"
  }
}

# analytics_read
#checkov:skip=CKV_AWS_338:One-year log retention is deferred for this non-production portfolio environment.
#checkov:skip=CKV_AWS_158:Customer-managed KMS for CloudWatch Logs is deferred for this non-production portfolio environment.
#checkov:skip=CKV_AWS_115:Reserved concurrency is deferred because this portfolio has low traffic and no downstream resource requiring concurrency protection yet.
resource "aws_cloudwatch_log_group" "analytics_read" {
  name = "/aws/lambda/${local.name_prefix}-analytics-read"
  # 本番運用開始後は retention_in_days を設定して、ログの保存期間を365にする
  retention_in_days = 7
  #  etention_in_days = 365
  tags = {
    Name = "${local.name_prefix}-analytics-read-log"
  }
}




############################################
# Lambda functions  analytics
############################################
#checkov:skip=CKV_AWS_115:Reserved concurrency is deferred because this portfolio has low traffic and no downstream resource requiring concurrency protection yet.
#checkov:skip=CKV_AWS_117:This Lambda intentionally runs outside a VPC because it only uses managed AWS services.
#checkov:skip=CKV_AWS_173:Customer-managed KMS for Lambda environment variables is deferred for this non-production portfolio environment.
#checkov:skip=CKV_AWS_272:Code signing is deferred because this portfolio currently uses a simple non-production deployment flow.
#checkov:skip=CKV_AWS_50:X-Ray tracing is deferred because CloudWatch Logs are sufficient for debugging in this non-production portfolio environment.
#checkov:skip=CKV_AWS_116:DLQ is deferred for this function until asynchronous failure handling is implemented.
# Lambda function
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
# Lambda functions  analytics read　shortCode の全日分を合計して返す　lambda 関数
############################################
#checkov:skip=CKV_AWS_117:This Lambda intentionally runs outside a VPC because it only uses managed AWS services.
#checkov:skip=CKV_AWS_173:Customer-managed KMS for Lambda environment variables is deferred for this non-production portfolio environment.
#checkov:skip=CKV_AWS_272:Code signing is deferred because this portfolio currently uses a simple non-production deployment flow.
#checkov:skip=CKV_AWS_116:DLQ is deferred for this function because it is not used for asynchronous failure handling in the current portfolio scope.
#checkov:skip=CKV_AWS_50:X-Ray tracing is deferred because CloudWatch Logs are sufficient for debugging in this non-production portfolio environment.

# 後でanalyticsのDLQの処理の追記をする予定があるため、analytics_read も DLQ 関連の checkov スキップを入れておきます。
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
  # cloiudwatchのロググループは aws_cloudwatch_log_group.analytics_read 
  depends_on = [
    aws_cloudwatch_log_group.analytics_read
  ]

  tags = {
    Name = "${local.name_prefix}-analytics-read"
  }
}

############################################
# Lambda functions  redirect
############################################

# Lambda function
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

  # 環境変数
  # LINK_TABLE_NAME redirect Lambda が読む DynamoDB テーブル名です
  # ANALYTICS_FUNCTION_NAME redirect Lambda から呼び出す analytics Lambda の関数名です  
  environment {
    variables = {
      #   LINK_TABLE_NAME         = aws_dynamodb_table.creators_links.name
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

