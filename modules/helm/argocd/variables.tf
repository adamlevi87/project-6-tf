# modules/argocd/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "chart_version" {
  type        = string
  default     = "8.2.3" # Latest stable as of July 2025
}

variable "domain_name" {
  type        = string
  description = "Domain name (e.g., dev.example.com)"
}

variable "argocd_allowed_cidr_blocks" {
  type        = list(string)
  description = "List of CIDR blocks allowed to access the ALB-argoCD"
}

variable "ingress_controller_class" {
  type        = string
  description = "Ingress Controller Class Resource Name"
  default     = "alb"
}

variable "node_group_security_groups" {
  type        = map(string)
  description = "Map of node group names to their security group IDs"
}

variable "service_account_name" {
  type        = string
  description = "The name of the Kubernetes service account to use for the Helm chart"
}

variable "release_name" {
  type        = string
  description = "The Helm release name"
}

variable "namespace" {
  type        = string
  description = "The Kubernetes namespace to install the Helm release into"
}

variable "acm_cert_arn" {
  description = "ARN of the ACM certificate to use for ALB HTTPS listener"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where RDS will be deployed"
  type        = string
}

variable "lbc_webhook_ready" {
  description = "AWS LBC webhook readiness signal"
  type        = string
}

variable "alb_group_name" {
  description = "Group name for ALB to allow sharing across multiple Ingress resources"
  type        = string
  default     = "alb_shared_group"  # Optional: override in dev/main.tf if needed
}

variable "backend_security_group_id" {
  description = "ID of the security group for the backend"
  type        = string
}

variable "frontend_security_group_id" {
  description = "ID of the security group for the frontend"
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

variable "secret_arn" {
  description = "ARN of the AWS Secrets Manager secret used by the application"
  type        = string
}

variable "github_application_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "github_gitops_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "github_org" {
  description = "GitHub organization"
  type        = string
}

variable "app_of_apps_path" {
  description = "Path within the GitOps repository where ArgoCD should look for Application manifests."
  type        = string
  default     = "apps"
}

variable "app_of_apps_target_revision" {
  description = "Branch or Git reference in the GitOps repository that ArgoCD should track."
  type        = string
  default     = "main"
}

# variable "github_oauth_client_id" {
#   description = "GitHub OAuth App Client ID for ArgoCD authentication"
#   type        = string
#   sensitive   = true
# }

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

variable "global_scheduling" {
  description = "Global scheduling configuration for all ArgoCD components"
  type = object({
    nodeSelector = map(string)
    tolerations = list(object({
      key      = string
      operator = string
      value    = string
      effect   = string
    }))
    affinity = object({
      podAntiAffinity = string  # "none", "soft", or "hard"
      nodeAffinity = object({
        type = string  # "none", "soft", or "hard"  
        matchExpressions = list(object({
          key      = string
          operator = string
          values   = list(string)
        }))
      })
    })
  })
}
