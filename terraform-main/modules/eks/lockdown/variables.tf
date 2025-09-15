# terraform-main/modules/eks/lockdown/variables.tf

variable "github_token" {
  description = "GitHub token for triggering workflows"
  type        = string
  sensitive   = true
}

variable "github_org" {
  description = "GitHub organization"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (terraform repo)"
  type        = string
}

variable "cluster_security_group_id" {
  description = "EKS cluster security group ID to lockdown"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}
