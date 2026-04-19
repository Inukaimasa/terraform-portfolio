# 後で Lambda が参照するテーブルの土台を作る。
# ■今回作るもの
# creators_links

# ■今やる内容
# テーブル名を決める
# PK / SK を定義する
#  PK: CREATOR#inukai
#  SK: PROFILE
# access_summary
# PK: CREATOR#inukai
# SK: DATE#2026-04-06#LINK#youtube

# ■まずは最小構成で作る
# この段階の完了条件
# dynamodb.tf に2テーブルがある
# terraform validate で通る


# hash_key = "PK" パーティションキー
# range_key = "SK" ソートキー

#  aws_dynamodb_table は DynamoDB テーブルそのものを作る リソース名は creators_links テーブル名も creators-links
# DynamoDB の複合主キーは、partition key と sort key の組み合わせです
#checkov:skip=CKV_AWS_119:Customer managed KMS for DynamoDB is deferred in this portfolio phase.
#checkov:skip=CKV_AWS_28:PITR is deferred in this portfolio phase due to cost considerations for non-production tables.
resource "aws_dynamodb_table" "creators_links" {
  name         = "creators-links"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }
  # attribute キーとして使う項目の型定義 S = 文字列
  attribute {
    name = "SK"
    type = "S"
  }

  #新規追加　運用始まってから有効にする。
  # point_in_time_recovery {
  #   enabled = true
  #   } 

  tags = {
    Name = "creators-links"
  }
}


# access-summaryテーブルも同様に定義します。
#checkov:skip=CKV_AWS_119:Customer managed KMS for DynamoDB is deferred in this portfolio phase.
#checkov:skip=CKV_AWS_28:PITR is deferred in this portfolio phase due to cost considerations for non-production tables.
resource "aws_dynamodb_table" "access_summary" {
  name         = "access-summary"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  #新規追加　運用始まってから有効にする。
  # point_in_time_recovery {
  #   enabled = true
  #   }
  tags = {
    Name = "access-summary"
  }
}

#checkov:skip=CKV_AWS_119:Customer managed KMS for DynamoDB is deferred in this portfolio phase.
#checkov:skip=CKV_AWS_28:PITR is deferred in this portfolio phase due to cost considerations for non-production tables.

resource "aws_dynamodb_table" "link_master" {
  name         = "${local.name_prefix}-link-master"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "short_code"

  attribute {
    name = "short_code"
    type = "S"
  }
  #新規追加
  #  point_in_time_recovery {
  #   enabled = true
  # }
  tags = {
    Name = "${local.name_prefix}-link-master"
  }
}
