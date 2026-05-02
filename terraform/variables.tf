variable "project_name" {
  description = "プロジェクト名"
  type        = string
  default     = "my-portfolio"
}

variable "environment" {
  description = "環境名"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "anthropic_api_key" {
  type        = string
  description = "Anthropic API Key for Claude"
  sensitive   = true
}

variable "slack_webhook_url" {
  type        = string
  description = "Slack Webhook URL for notifications"
  sensitive   = true



}