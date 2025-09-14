# modules/secrets-manager/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "secret_keys" {
  description = "List of secret keys for iteration (non-sensitive)"
  type        = list(string)
  default     = []
}

variable "app_secrets_config" {
  description = "Map of application secrets (key → JSON string of env vars)"
  type = map(object({
    description   = string
    secret_value  = string
  }))
  default = {}
  sensitive   = true
}


variable "secrets_config_with_passwords" {
  description = "Map of Configurations of secrets to create"
  type = map(object({
    description        = string
    generate_password  = bool
    password_length    = optional(number, 16)
    password_special   = optional(bool, true)
    secret_value       = optional(string, "")
    password_override_special = optional(string, "")
  }))
}
