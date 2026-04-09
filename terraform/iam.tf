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

# aws_iam_role は Lambda が使うロールを作る
# aws_iam_role_policy_attachment は そのロールに権限を付ける
# assume_role_policy は 誰がそのロールを使えるかを決める


# Lambda 共通の assume role policy
# redirect 用 IAM ロール
# redirect 用の基本ログ権限
# redirect 用の追加権限
# analytics 用 IAM ロール
# analytics 用の基本ログ権限
# analytics 用の追加権限


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
# # Lambda が CloudWatch Logs に書くための基本権限
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
#Lambdaアプリ用追加権限
resource "aws_iam_role_policy" "lambda_app_custom" {
  name ="lambda-app-custom"
  role = aws_iam_role.lambda_exec_role.id

  policy =jsonencode({
    Version  ="2012-10-17"
    Statement =[{
      Sid= "ReadLinkMaster"
      Effect ="Allow"
      Action = [
        "dynamodb:GetItem"
      ]
      # redirect Lambda が link_master からshort_code のリンク先を読むためです。dynamodb:GetItem
      Resource = aws_dynamodb_table.link_master.arn
    },
    {
    # dynamodb:UpdateItem, dynamodb:Query
        Sid    = "UpdateAndQueryAccessSummary"
        Effect = "Allow"
        Action = [
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.access_summary.arn
    },
  {
    # redirect Lambda がanalytics Lambda を非同期呼び出しするためです。
    # 人が見て分かりやすくするためのラベル
    Sid ="InvokeAnalyticsLambda"
    Effect ="Allow"
   # Lambda 関数を呼び出す操作 redirect/app.py
#     lambda_client.invoke(
#     FunctionName=ANALYTICS_FUNCTION_NAME,
#     InvocationType="Event",
#     Payload=json.dumps(payload).encode("utf-8"),
# )


    Action = [
      "lambda:InvokeFunction"
      
    ]
    # どの Lambda に対して許可するか
    Resource =aws_lambda_function.analytics.arn
      }
    ]
  })
}