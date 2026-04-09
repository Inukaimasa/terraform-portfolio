# 前提。

# backend/redirect/app.py
# backend/analytics/app.py
# Python ハンドラは def lambda_handler(event, context):
# iam.tf に 実行ロールがすでにある
# aws_iam_role.redirect_lambda_exec
# aws_iam_role.analytics_lambda_exec


# これで参照しているものは、別ファイルで定義済か確認する。
#  local.name_prefix
#  aws_iam_role.redirect_lambda_exec
#  aws_iam_role.analytics_lambda_exec
#  aws_dynamodb_table.link_master
#  aws_dynamodb_table.access_summary

# 下記コマンドを使用して検索をする
# grep -R 'name_prefix' terraform
# grep -R 'redirect_lambda_exec' terraform
# grep -R 'analytics_lambda_exec' terraform
# grep -R 'link_master' terraform
# grep -R 'access_summary' terraform

