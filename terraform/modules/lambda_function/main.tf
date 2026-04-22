# 「module本体を用意した」 状態です。

# Lambda 1本を動かすのに必要な部品をまとめて作る本体です。

# ソースコードを zip 化する
# Lambda 用 IAM Role を作る
# ログ出力用の権限を付ける
# CloudWatch Logs の保存先を作る
# Lambda 関数を作る　実装
# 「コードを配置する」＋「動かす権限を与える」＋「ログを出せるようにする」


# --------------------------------------------
# Lambda のソースコード一式を zip 化する
# --------------------------------------------
# data は「リソースを作る」のではなく、
# 既存情報を参照したり、計算結果を作ったりするためのものです。
# ここでは backend/redirect のようなソースディレクトリを zip にまとめます。

data "archive_file" "this" {
  type = "zip"
  # 呼び出し元(module "redirect_lambda") から渡されたソースコードの場所
  source_dir = var.source_dir
  # zip ファイルの出力先
  # path.module は「この module 自身のディレクトリ」
  # つまり modules/lambda_function/ の中に zip を作る
  output_path = "${path.module}/${var.lambda_name}.zip"

}
# --------------------------------------------
# Lambda が使う IAM Role を作る
# --------------------------------------------

resource "aws_iam_role" "this" {
  name = "${var.lambda_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# --------------------------------------------
# Lambda の基本実行ポリシーをアタッチする
# --------------------------------------------
# これを付けることで、CloudWatch Logs へログ出力できるようになります。
resource "aws_iam_role_policy_attachment" "basic_execution" {
  role = aws_iam_role.this.name
  # AWS 管理ポリシー
  # Lambda の基本ログ出力権限
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --------------------------------------------
# CloudWatch Log Group を事前に作る
# --------------------------------------------
# Lambda 実行時のログ保存先です。
# Lambda が初回実行時に自動作成することもありますが、
# Terraform で管理したいので明示的に作っています。

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.lambda_name}"
  retention_in_days = 7
}

# --------------------------------------------
# Lambda 関数本体を作る
# --------------------------------------------

resource "aws_lambda_function" "this" {
  # Lambda 関数名
  function_name = var.lambda_name
  # Lambda が実行時に使う IAM Role
  role = aws_iam_role.this.arn
  # app.py の lambda_handler なら "app.lambda_handler"
  handler = var.handler
  # ランタイム
  # 例: python3.13
  runtime = var.runtime
  # zip ファイルの場所を指定
  filename = data.archive_file.this.output_path

  # コード差分検知用のハッシュ
  # ソースコードが変わったら Lambda 更新対象になる
  source_code_hash = data.archive_file.this.output_base64sha256
  #タイムアウト時間（秒）
  timeout = var.timeout
  #メモリサイズ（MB）
  memory_size = var.memory_size
  # Lambda の環境変数を指定
  environment {
    variables = var.environment_variables
  }
  # 明示的な依存関係
  # ログ出力権限と Log Group が先にできてから Lambda を作る
  depends_on = [
    aws_iam_role_policy_attachment.basic_execution,
    aws_iam_role_policy.app_permissions,
    aws_cloudwatch_log_group.this
  ]
}

resource "aws_iam_role_policy" "app_permissions" {
  name = "${var.lambda_name}-app-permissions"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowReadLinkTable"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem"
        ]
        Resource = var.link_table_arn
      },
      {
        Sid    = "AllowInvokeAnalyticsLambda"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = var.analytics_function_arn
      }
    ]
  })
}