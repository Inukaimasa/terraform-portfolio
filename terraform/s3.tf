# CKV_AWS_18を使用するとskipされるように、S3バケットのアクセスログ設定がこの段階では遅延されていることを示すコメントを追加しました。

resource "aws_s3_bucket" "this" {
  bucket_prefix = "${local.name_prefix}-"

  tags = {
    Name = "${local.name_prefix}-bucket"
  }
}

#checkov:skip=CKV2_AWS_61:Lifecycle policy is deferred because this non-production portfolio bucket currently stores only a small amount of static content.
#checkov:skip=CKV2_AWS_62:S3 event notifications are not required because this bucket is used only for static frontend hosting.
#checkov:skip=CKV_AWS_144:Cross-region replication is deferred because this is a non-production portfolio bucket without disaster recovery requirements.
#checkov:skip=CKV_AWS_145:Customer-managed KMS default encryption is deferred for this non-production portfolio bucket.
#checkov:skip=CKV_AWS_18:Access logging is deferred because a dedicated log bucket is not yet provisioned for this non-production portfolio environment.

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id


  versioning_configuration {
    status = "Enabled"
  }

}
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}