# terraform-main/modules/s3/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "force_destroy" {
  description = "Allow force destruction of bucket even if it contains objects"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for S3 bucket encryption"
  type        = string
}

variable "s3_policy_deny_rule_name" {
  description = "Name of the S3 policy deny rule to modify"
  type        = string
}

variable "allowed_principals" {
  description = "List of additional IAM role ARNs that should have access to the S3 bucket"
  type        = list(string)
  default     = []
}

variable "enable_lifecycle_policy" {
  description = "Enable S3 lifecycle policy for cost optimization"
  type        = bool
  default     = true
}

variable "data_retention_days" {
  description = "Number of days to retain data before deletion (0 = keep forever)"
  type        = number
  default     = 0
  validation {
    condition     = var.data_retention_days >= 0
    error_message = "Data retention days must be non-negative."
  }
}
