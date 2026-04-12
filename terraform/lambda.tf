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
############################################
# CloudWatch Logs
############################################
resource "aws_cloudwatch_log_group" "redirect" {
  name              = "/aws/lambda/${local.name_prefix}-redirect"
  retention_in_days = 14

  tags = {
    Name = "${local.name_prefix}-redirect-log"
  }
}
resource "aws_cloudwatch_log_group" "analytics" {
  name              = "/aws/lambda/${local.name_prefix}-analytics"
  retention_in_days = 14

  tags = {
    Name = "${local.name_prefix}-analytics-log"
  }
}
############################################
# Lambda functions  analytics
############################################

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
# Lambda functions  redirect
############################################

# Lambda function
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

