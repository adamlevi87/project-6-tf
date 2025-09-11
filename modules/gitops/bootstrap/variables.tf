# modules/gitops/bootstrap/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming and ArgoCD project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

# variable "gitops_repo_owner" {
#   description = "GitHub username/organization that owns the GitOps repository"
#   type        = string
# }

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

# variable "app_name" {
#   description = "Application name for project description"
#   type        = string
#   default     = "project-5"
# }

# variable "aws_region" {
#   description = "AWS region"
#   type        = string
# }

# ECR Repository URLs
variable "ecr_frontend_repo_url" {
  description = "ECR repository URL for frontend"
  type        = string
}

# variable "ecr_backend_repo_url" {
#   description = "ECR repository URL for backend"
#   type        = string
# }

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

# variable "frontend_external_secret_name" {
#   description = "External secret name for frontend"
#   type        = string
# }

# variable "frontend_aws_secret_key" {
#   description = "AWS secret key for frontend environment variables"
#   type        = string
# }

# # Backend Configuration
# variable "backend_namespace" {
#   description = "Kubernetes namespace for backend"
#   type        = string
#   default     = "backend"
# }

# variable "backend_service_account_name" {
#   description = "Service account name for backend"
#   type        = string
#   default     = "backend-sa"
# }

# variable "backend_container_port" {
#   description = "Container port for backend"
#   type        = number
#   default     = 3000
# }

# variable "backend_ingress_host" {
#   description = "Ingress host for backend"
#   type        = string
# }

# variable "backend_external_dns_hostname" {
#   description = "External DNS hostname for backend"
#   type        = string
# }

# variable "backend_external_secret_name" {
#   description = "External secret name for backend"
#   type        = string
# }

# variable "backend_aws_secret_key" {
#   description = "AWS secret key for backend environment variables"
#   type        = string
# }

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

# variable "argocd_project_name" {
#   description = "ArgoCD project name (defaults to project_tag)"
#   type        = string
#   default     = ""
# }

# # Optional Configuration
# variable "create_pr" {
#   description = "Whether to create a pull request automatically"
#   type        = bool
#   default     = true
# }

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

# Enable/disable which applications to update
# variable "update_frontend" {
#   description = "Whether to update frontend configuration"
#   type        = bool
#   default     = true
# }

# variable "update_backend" {
#   description = "Whether to update backend configuration"
#   type        = bool
#   default     = true
# }

variable "bootstrap_mode" {
  description = "Whether to create all GitOps files (project + applications + values) - bootstrap mode"
  type        = bool
  default     = false
}

# variable "applications" {
#   description = "List of applications to create (for bootstrap mode)"
#   type        = list(string)
# }

variable "update_apps" {
  description = "Whether to update infrastructure values for both frontend and backend"
  type        = bool
  default     = false
}

variable "current_files_data" {
  description = "Map of current file data from GitHub repository"
  type = map(object({
    content = string
    # Add other attributes as needed
  }))
}

variable "gitops_repo_name" {
  description = "GitHub repository name (from data source)"
  type        = string
}

variable "github_token" {
  description = "GitHub PAT with access to manage secrets"
  type        = string
  sensitive   = true
}
