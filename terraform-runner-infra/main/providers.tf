# terraform-runner-infra/main/providers.tf

terraform {
  # latest versions of each provider for 09/2025
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
