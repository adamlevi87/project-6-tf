# modules/apps/frontend/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN from the EKS module"
  type        = string
}

variable "oidc_provider_url" {
  type        = string
  description = "OIDC provider URL (e.g. https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLEDOCID)"
}

variable "namespace" {
  description = "namespace used"
  type        = string
}

variable "service_account_name" {
  description = "service_account_name name"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for S3 bucket encryption"
  type        = string
}
