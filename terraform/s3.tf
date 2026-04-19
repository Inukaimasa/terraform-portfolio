############################################
# S3 bucket for frontend hosting
############################################

#checkov:skip=CKV2_AWS_61:Lifecycle policy is deferred because this non-production portfolio bucket currently stores only a small amount of static content.
#checkov:skip=CKV2_AWS_62:S3 event notifications are not required because this bucket is used only for static frontend hosting.
#checkov:skip=CKV_AWS_144:Cross-region replication is deferred because this is a non-production portfolio bucket without disaster recovery requirements.
#checkov:skip=CKV_AWS_145:Customer-managed KMS default encryption is deferred for this non-production portfolio bucket.
#checkov:skip=CKV_AWS_18:Access logging is deferred because a dedicated log bucket is not yet provisioned for this non-production portfolio environment.
resource "aws_s3_bucket" "this" {
  bucket_prefix = "${local.name_prefix}-"

  tags = {
    Name = "${local.name_prefix}-bucket"
  }
}

############################################
# Public Access Block
############################################
# CKV2_AWS_6 対応
# S3 バケットを意図せず public にしないための設定
# CloudFront 経由で配信する前提なので、S3 自体は private のままにする
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

############################################
# Versioning
############################################
# CKV_AWS_21 対応
# 誤ってファイルを上書き・削除した時に戻しやすくするための設定
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

############################################
# Outputs are defined in outputs.tf
############################################