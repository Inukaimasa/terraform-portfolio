# 目的

# Lambda が動くための権限を作る。

# ■今回やること
# Lambda 実行用 Role
# CloudWatch Logs に書ける Policy
# ■まだやらなくていいこと
# DynamoDB の細かい読み書き権限
# ■API Gateway 用の細かい制御
# この段階の完了条件
# Lambda 用 Role が1つある
# basic execution 相当の権限がついている

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "lambda-exec-role"
  }
}
# lambdaで使用するIAMロールを定義しています。Lambdaがこのロールを引き受けることができるように、信頼ポリシー（assume_role_policy）を設定しています。
# このロールには、LambdaがCloudWatch Logsに書き込むための基本的な実行権限が必要です。
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
