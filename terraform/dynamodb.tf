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

  tags = {
    Name = "creators-links"
  }
}
# access-summaryテーブルも同様に定義します。

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

  tags = {
    Name = "access-summary"
  }
}


