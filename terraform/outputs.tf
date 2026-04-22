# 重要な考え方

# outputs.tf は 2種類 あります。

# 1. module 側の outputs
# terraform/modules/lambda_function/outputs.tf
# 役割:
# module の中で作った Lambda 名
# Lambda ARN
# Log Group 名

# 2. root 側の outputs
# 場所:
# root module で作った S3 の情報を出す
# 呼び出した module の出力を表示する
# terraform/outputs.tf

# output "project_name" {
#   description = "プロジェクト名"
#   value       = var.project_name
# }

# output "environment" {
#   description = "環境名"
#   value       = var.environment
# }

# output "aws_region" {
#   description = "AWSリージョン"
#   value       = var.aws_region
# }


output "s3_bucket_name" {
  description = "S3バケット名"
  value       = aws_s3_bucket.this.bucket
}
output "s3_bucket_arn" {
  description = "S3バケットARN"
  value       = aws_s3_bucket.this.arn
}
output "s3_bucket_region" {
  description = "S3バケットのリージョン"
  value       = aws_s3_bucket.this.bucket_region
}

output "s3_bucket_id" {
  description = "S3バケットID"
  value       = aws_s3_bucket.this.id
}

# 新規追加
output "redirect_lambda_function_name" {
  value = module.redirect_lambda.lambda_name
}

output "redirect_lambda_function_arn" {
  value = module.redirect_lambda.lambda_arn
}

output "redirect_lambda_log_group_name" {
  value = module.redirect_lambda.log_group_name
}

