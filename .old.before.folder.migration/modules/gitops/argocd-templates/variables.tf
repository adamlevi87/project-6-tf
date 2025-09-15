# modules/gitops/argocd-templates/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "argocd_namespace" {
  description = "ArgoCD namespace"
  type        = string
}

variable "github_org" {
  description = "GitHub organization"
  type        = string
}

variable "github_gitops_repo" {
  description = "GitHub GitOps repository name"
  type        = string
}

variable "github_application_repo" {
  description = "GitHub application repository name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "app_of_apps_path" {
  description = "Path within GitOps repo for app-of-apps"
  type        = string
}

variable "app_of_apps_target_revision" {
  description = "Git branch/revision for app-of-apps"
  type        = string
}
