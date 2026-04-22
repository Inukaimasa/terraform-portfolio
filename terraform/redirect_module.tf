# modules/lambda_function/main.tf
# modules/lambda_function/variables.tf
# modules/lambda_function/outputs.tf
# の内容をまとめて、terraform/redirect_module.tf に記載します。

# terraform/modules/lambda_function/variables.tf
# description = "redirect-lambda"を参照

module "redirect_lambda" {
  source = "./modules/lambda_function"

  lambda_name = "redirect-lambda"
  source_dir  = "${path.root}/../backend/redirect"
  handler     = "app.lambda_handler"
  runtime     = "python3.13"
  timeout     = 10
  memory_size = 128

  environment_variables = {
    LOG_LEVEL               = "INFO"
    LINK_TABLE_NAME         = aws_dynamodb_table.link_master.name
    ANALYTICS_FUNCTION_NAME = aws_lambda_function.analytics.function_name
  }
  link_table_arn         = aws_dynamodb_table.link_master.arn
  analytics_function_arn = aws_lambda_function.analytics.arn

}