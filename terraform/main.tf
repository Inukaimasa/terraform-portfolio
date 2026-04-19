locals {
  name_prefix = "${var.project_name}-${var.environment}"
}
# - S3
# resource "aws_s3_bucket" "this" {
#   bucket_prefix = "${local.name_prefix}-"
#   tags = {
#     Name = "${local.name_prefix}-bucket"
#   }
# }


# 今後ここに以下を追加予定

# - CloudFront
# - API Gateway
# - Lambda
# - DynamoDB
# - CloudWatch