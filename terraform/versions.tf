# 2. terraform/versions.tf
# Terraform本体とAWS Providerのバージョン条件


terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # hashicorp/archive は “zip を作るための Terraform provider を、公式 Registry から取ってくる指定”
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.5"
    }
  }

}