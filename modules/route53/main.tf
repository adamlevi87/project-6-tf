# modules/route53/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

resource "aws_route53_zone" "this" {
  name = var.domain_name
  comment = "Hosted zone for ${var.project_tag}"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
  }
}
