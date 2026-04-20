# S3 バケット名は全世界で一意なので、重複したら少し変えてください。
provider "aws" {
  region = "ap-northeast-1"
}


resource "aws_s3_bucket" "tfstate" {
  bucket = "my-protfolio-tfstate-20260420"
}


resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

output "tfstate_bucket_name" {
  value = aws_s3_bucket.tfstate.id
}

