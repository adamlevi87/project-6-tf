# terraform-requirements/variables.tf

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "aws_s3_bucket_name" {
  description = "Terraform backend - S3 bucket name to create"
  type        = string
}

variable "project_tag" {
  description = "Tag used to label resources"
  type        = string
}

variable "environment" {
  description = "environment name for tagging resources"
  type        = string
}

variable "aws_dynamodb_table_name" {
  description = "Terraform backend - Dynamodb table name"
  type        = string
}

variable "aws_iam_role_github_actions_name" {
  description = "AWS iam role name for github actions"
  type        = string
}

variable "github_org" {
  type        = string
  description = "GitHub organization or user"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
}

variable "kms_allowed_users" {
  description = "List of IAM users allowed to assume the GitHub Actions role"
  type        = list(string)
}
