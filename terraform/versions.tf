# 2. terraform/versions.tf
# Terraform本体とAWS Providerのバージョン条件


terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}