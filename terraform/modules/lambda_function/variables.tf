# 「module本体を用意した」 状態です。
# 「この module を使うとき、外から何を渡せるのか」
# function_nam,source_dir,handler,runtimeなどは、全部この variables.tf 側で受け取っています。
# module の外から設定可能な項目の一覧表 ← 注文を受け取る窓口
# --------------------------------------------
# Lambda 関数名
# --------------------------------------------

variable "lambda_name" {
  description = "redirect-lambda"
  type        = string
}

# --------------------------------------------
# Lambda ソースコードのディレクトリ
# --------------------------------------------
# 例: ${path.root}/../backend/redirect
# archive_file がこのディレクトリを zip 化する
variable "source_dir" {
  type        = string
  default     = ""
  description = "Lambda source directory"
}

# --------------------------------------------
# handler
# --------------------------------------------
# 例: app.lambda_handler
#どのファイルのどの関数を実行するか
variable "handler" {
  type        = string
  description = "Lambda handler"
}

# --------------------------------------------
# runtime
# --------------------------------------------
# 例: python3.13
variable "runtime" {
  type        = string
  description = "Lambda runtime"
}
# --------------------------------------------
# timeout
# --------------------------------------------

# Lambda が何秒まで実行してよいか
# 指定がなければ 10 秒
variable "timeout" {
  type        = number
  default     = 10
  description = "Lambda timeout in seconds"
}
# --------------------------------------------
# memory_size
# --------------------------------------------  
# Lambda に割り当てるメモリサイズ（MB）
# 指定がなければ 128 MB
variable "memory_size" {
  type        = number
  default     = 128
  description = "Lambda memory size in MB"
}
# --------------------------------------------
# Lambda の環境変数
# --------------------------------------------
# Lambda に渡す環境変数の定義
variable "environment_variables" {
  type        = map(string)
  default     = {}
  description = "Lambda environment variables"
}


variable "link_table_arn" {
  type        = string
  description = "DynamoDB table ARN for redirect lookup"
}
variable "analytics_function_arn" {
  type        = string
  description = "Analytics Lambda ARN"
}
