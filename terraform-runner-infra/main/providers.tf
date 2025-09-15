# terraform-runner-infra/main/providers.tf

terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_tag
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "terraform-runner-infra"
    }
  }
}
