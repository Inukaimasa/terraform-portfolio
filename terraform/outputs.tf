output "project_name" {
  description = "プロジェクト名"
  value       = var.project_name
}

output "environment" {
  description = "環境名"
  value       = var.environment
}

output "aws_region" {
  description = "AWSリージョン"
  value       = var.aws_bucket_region
}
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