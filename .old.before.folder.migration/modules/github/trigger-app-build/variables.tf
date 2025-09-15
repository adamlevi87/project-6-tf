# modules/github/trigger-app-build/variables.tf

variable "github_token" {
  description = "GitHub PAT for triggering workflows"
  type        = string
  sensitive   = true
}

variable "github_org" {
  description = "GitHub organization"
  type        = string
}

variable "github_application_repo" {
  description = "GitHub application repository name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}
