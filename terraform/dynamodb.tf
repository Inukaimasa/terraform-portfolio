############################################
# DynamoDB tables
############################################

# DynamoDB テーブルを定義します。
#
# 使い分け
# 1. creators_links
#    - 将来の creator_id / link_id ベースの拡張用テーブル
#    - 現在の redirect Lambda では直接使っていない
#
# 2. access_summary
#    - analytics Lambda / analytics_read Lambda が使う集計テーブル
#    - アクセス数や最終アクセス時刻などを保持する想定
#
# 3. link_master
#    - redirect Lambda が short_code から target_url を引くためのテーブル
#    - 現在のリダイレクト処理の中心

############################################
# creators_links
############################################
# 役割:
# creator ごとの link 一覧を持つ拡張用テーブルです。
# 今は redirect Lambda から直接参照していませんが、
# 将来 creator_id / link_id を正式に管理したくなった時に使う想定です。
#
# Checkov 対応:
# CKV_AWS_28  = PITR（Point In Time Recovery）
#   -> 今は非本番・検証環境なので、コストを考慮して後回し
#
# CKV_AWS_119 = Customer Managed KMS
#   -> DynamoDB の customer-managed KMS は本番寄せの強化項目として後回し
#
# キー設計:
# PK = creator 単位のまとまり
# SK = link 単位の識別子
# という設計に拡張しやすい形です。
#checkov:skip=CKV_AWS_28:PITR is deferred due to cost considerations for this non-production portfolio table.
#checkov:skip=CKV_AWS_119:Customer managed KMS for DynamoDB is deferred in this non-production portfolio phase.
resource "aws_dynamodb_table" "creators_links" {
  name         = "creators-links"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  # PK = Partition Key
  # creator 単位でデータをまとめる時に使う想定
  attribute {
    name = "PK"
    type = "S"
  }

  # SK = Sort Key
  # link_id や種別など、creator 配下の項目を区別する時に使う想定
  attribute {
    name = "SK"
    type = "S"
  }

  tags = {
    Name = "creators-links"
  }
}

############################################
# access_summary
############################################
# 役割:
# analytics Lambda / analytics_read Lambda が使うアクセス集計テーブルです。
#
# どこと紐づいているか:
# - analytics Lambda
#   ACCESS_SUMMARY_TABLE_NAME = aws_dynamodb_table.access_summary.name
# - analytics_read Lambda
#   ACCESS_SUMMARY_TABLE_NAME = aws_dynamodb_table.access_summary.name
#
# 想定用途:
# short_code ごとの access_count
# last_accessed_at
# 日別集計
# などを保持する想定です。
#
# キー設計:
# PK = 集計対象のまとまり
# SK = 日付や明細の区別
#
# 例:
# PK = "SHORTCODE#abc123"
# SK = "DATE#2026-04-19"
#
# Checkov 対応:
# PITR と customer-managed KMS は今は後回しにしています。
#checkov:skip=CKV_AWS_28:PITR is deferred due to cost considerations for this non-production portfolio table.
#checkov:skip=CKV_AWS_119:Customer managed KMS for DynamoDB is deferred in this non-production portfolio phase.
resource "aws_dynamodb_table" "access_summary" {
  name         = "access-summary"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  # 集計対象のまとまり用キー
  attribute {
    name = "PK"
    type = "S"
  }

  # 日付や明細の区別用キー
  attribute {
    name = "SK"
    type = "S"
  }

  tags = {
    Name = "access-summary"
  }
}

############################################
# link_master
############################################
# 役割:
# redirect Lambda が short_code から target_url を引くためのマスタテーブルです。
#
# どこと紐づいているか:
# - redirect Lambda
#   LINK_TABLE_NAME = aws_dynamodb_table.link_master.name
#
# 現在の redirect 処理の流れ:
# 1. API Gateway から shortCode を受け取る
# 2. redirect Lambda が link_master を読む
# 3. short_code に対応する target_url を取得する
# 4. 302 リダイレクトを返す
#
# キー設計:
# short_code をそのままパーティションキーにしています。
# 1 short_code = 1 リンク のシンプルな構成です。
#
# 例:
# short_code = "abc123"
# target_url = "https://example.com"
#
# Checkov 対応:
# PITR と customer-managed KMS は今は後回しにしています。
#checkov:skip=CKV_AWS_28:PITR is deferred due to cost considerations for this non-production portfolio table.
#checkov:skip=CKV_AWS_119:Customer managed KMS for DynamoDB is deferred in this non-production portfolio phase.
resource "aws_dynamodb_table" "link_master" {
  name         = "${local.name_prefix}-link-master"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "short_code"

  # short_code をキーに 1件取得するためのキー
  attribute {
    name = "short_code"
    type = "S"
  }

  tags = {
    Name = "${local.name_prefix}-link-master"
  }
}