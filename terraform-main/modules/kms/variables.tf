# terraform-main/modules/kms/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "deletion_window_in_days" {
  description = "Number of days before the KMS key is deleted after destruction"
  type        = number
  default     = 7
  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "Deletion window must be between 7 and 30 days."
  }
}

variable "enable_key_rotation" {
  description = "Enable automatic key rotation"
  type        = bool
  default     = true
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}
