# modules/argocd/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "alb_security_groups" {
  description = "Security groups for ALB (comma-separated)"
  type        = string
}

variable "namespace" {
  type        = string
  description = "The Kubernetes namespace to install the Helm release into"
}

variable "github_org" {
  description = "GitHub organization"
  type        = string
}

variable "release_name" {
  type        = string
  description = "The Helm release name"
}

variable "chart_version" {
  type        = string
  default     = "8.2.3" # Latest stable as of July 2025
}

variable "service_account_name" {
  type        = string
  description = "The name of the Kubernetes service account to use for the Helm chart"
}

variable "domain_name" {
  type        = string
  description = "Domain name (e.g., dev.example.com)"
}

variable "ingress_controller_class" {
  type        = string
  description = "Ingress Controller Class Resource Name"
}

variable "alb_group_name" {
  description = "Group name for ALB to allow sharing across multiple Ingress resources"
  type        = string
  default     = "alb_shared_group"  # Optional: override in dev/main.tf if needed
}

variable "argocd_allowed_cidr_blocks" {
  type        = list(string)
  description = "List of CIDR blocks allowed to access the ALB-argoCD"
}

variable "acm_cert_arn" {
  description = "ARN of the ACM certificate to use for ALB HTTPS listener"
  type        = string
}

variable "github_admin_team" {
  description = "GitHub team name for admin access to ArgoCD"
  type        = string
  default     = "devops"
}

variable "github_readonly_team" {
  description = "GitHub team name for readonly access to ArgoCD"
  type        = string
  default     = "developers"
}

variable "argocd_github_sso_secret_name" {
  description = "Name of the GitHub SSO secret for ArgoCD"
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

variable "argocd_project_yaml" {
  description = "Rendered Project YAML from argocd-templates module"
  type        = string
}

variable "argocd_app_of_apps_yaml" {
  description = "Rendered App-of-Apps YAML from argocd-templates module"
  type        = string
}

variable "secret_arn" {
  description = "ARN of the AWS Secrets Manager secret used by the application"
  type        = string
}
