# terraform-main/modules/repo_ecr_access/variables.tf

variable "project_tag" {
  description = "Project tag used for naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/stage/prod)"
  type        = string
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
}

variable "aws_iam_openid_connect_provider_github_arn" {
  type        = string
  description = "github provider arn [created beforhand, using .requirements folder]"
  sensitive   = true
}

variable "github_org" {
  type        = string
  description = "GitHub organization or user"
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs that GitHub Actions can access"
  type        = list(string)
}
