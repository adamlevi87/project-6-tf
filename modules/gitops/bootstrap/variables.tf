# modules/gitops/bootstrap/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming and ArgoCD project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "github_gitops_repo" {
  description = "Name of the GitOps repository"
  type        = string
}

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_application_repo" {
  description = "GitHub application repository name"
  type        = string
}

# ECR Repository URLs
variable "ecr_frontend_repo_url" {
  description = "ECR repository URL for frontend"
  type        = string
}

# Frontend Configuration
variable "frontend_namespace" {
  description = "Kubernetes namespace for frontend"
  type        = string
  default     = "frontend"
}

variable "frontend_service_account_name" {
  description = "Service account name for frontend"
  type        = string
  default     = "frontend-sa"
}

variable "frontend_container_port" {
  description = "Container port for frontend"
  type        = number
  default     = 80
}

variable "frontend_ingress_host" {
  description = "Ingress host for frontend"
  type        = string
}

variable "frontend_external_dns_hostname" {
  description = "External DNS hostname for frontend"
  type        = string
}

variable "auto_merge_pr" {
  description = "Whether to auto-merge the created PR"
  type        = bool
}

variable "argocd_project_yaml" {
  description = "Rendered Project YAML from argocd-templates module"
  type        = string
  default     = ""
}

variable "argocd_app_of_apps_yaml" {
  description = "Rendered App-of-Apps YAML from argocd-templates module"
  type        = string
  default     = ""
}

# Shared ALB Configuration
variable "alb_group_name" {
  description = "ALB group name for shared load balancer"
  type        = string
}

variable "alb_security_groups" {
  description = "Security groups for ALB (comma-separated)"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
}

# ArgoCD Configuration
variable "argocd_namespace" {
  description = "ArgoCD namespace"
  type        = string
  default     = "argocd"
}

variable "branch_name_prefix" {
  description = "Prefix for auto-generated branch names"
  type        = string
  default     = "terraform-updates"
}

variable "target_branch" {
  description = "Target branch for pull requests"
  type        = string
  default     = "main"
}

variable "frontend_argocd_app_name" {
  description = "ArgoCD application name for the frontend"
  type        = string
}

variable "frontend_helm_release_name" {
  description = "Helm release name for the frontend deployment"
  type        = string
}

variable "bootstrap_mode" {
  description = "Whether to create all GitOps files (project + applications + values) - bootstrap mode"
  type        = bool
  default     = false
}

variable "update_apps" {
  description = "Whether to update infrastructure values for both frontend and backend"
  type        = bool
  default     = false
}

variable "github_token" {
  description = "GitHub PAT with access to manage secrets"
  type        = string
  sensitive   = true
}
