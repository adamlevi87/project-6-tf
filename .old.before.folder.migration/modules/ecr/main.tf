# modules/ecr/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

resource "aws_ecr_repository" "this" {
  for_each             = toset(var.ecr_repositories_applications)

  name                 = "${var.ecr_repository_name}-${var.environment}-${each.key}"
  force_delete         = true
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
  
  tags = {
    Project = var.project_tag
    Environment = var.environment
    Application = each.key
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Expire untagged images older than 14 days",
        selection = {
          tagStatus   = "untagged",
          countType   = "sinceImagePushed",
          countUnit   = "days",
          countNumber = 14
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}
