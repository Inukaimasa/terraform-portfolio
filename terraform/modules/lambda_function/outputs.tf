# 「module本体を用意した」 状態です。
# variables.tf 材料を受け取る
# main.tf 実際に料理する
# outputs.tf 料理の完成品を外へ出す

# aws_lambda_function.this.function_name
# aws_lambda_function.this.arn
# aws_cloudwatch_log_group.this.name

# を、module の外から使えるようにする 宣言です。「この3つの値は外に渡していいです」
# root 側では、child module の output
# module.redirect_lambda.lambda_name
# module.redirect_lambda.lambda_arn
# module.redirect_lambda.log_group_name

# this = その module 内での名前 main.tf 内で aws_lambda_function というリソースを this という名前で作っている
# --------------------------------------------
# 作成した Lambda 関数名を module の外へ返す　root(親のOUTPUTに表示するため)
# --------------------------------------------
output "lambda_name" {
  value = aws_lambda_function.this.function_name
}
# --------------------------------------------
# 作成した Lambda 関数の ARN を module の外へ返す
# --------------------------------------------

output "lambda_arn" {
  value = aws_lambda_function.this.arn
}
# --------------------------------------------
#  作成した CloudWatch Log Group 名を module の外へ返す
# --------------------------------------------

output "log_group_name" {
  value = aws_cloudwatch_log_group.this.name
}
# --------------------------------------------