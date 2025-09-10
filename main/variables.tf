# main/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "aws_provider_version" {
  description = "AWS provider version"
  type        = string
}

variable "kubernetes_provider_version" {
  description = "Kubernetes provider version"
  type        = string
}

variable "helm_provider_version" {
  description = "Helm provider version"
  type        = string
}

variable "github_provider_version" {
  description = "GitHub provider version"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "enable_lifecycle_policy" {
  description = "Enable or disable S3 bucket lifecycle policy"
  type        = bool
}

variable "ecr_repository_name" {
  description = "Base name prefix for all ECR repositories"
  type        = string
}

variable "ecr_repositories_applications" {
  description = "List of application names to create ECR repositories for"
  type        = list(string)
}

variable "domain_name" {
  type        = string
  description = "The root domain to configure (e.g., yourdomain.com)"
}

variable "subdomain_name" {
  type        = string
  description = "The subdomain for the app (e.g., chatbot)"
}

# EKS Cluster Configuration
variable "eks_kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "eks_api_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the cluster endpoint"
  type        = list(string)
  default     = []
}

# EKS Node Group Configuration
variable "eks_node_groups" {
  description = "Map of EKS node group configurations"
  type = map(object({
    instance_type     = string
    ami_id           = string
    desired_capacity = number
    max_capacity     = number
    min_capacity     = number
    labels           = map(string)
    taints           = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
  
  validation {
    condition = length(var.eks_node_groups) > 0
    error_message = "At least one node group must be defined."
  }
}

# EKS Logging Configuration
variable "cluster_enabled_log_types" {
  description = <<EOT
List of cluster log types to enable.
Available: api, audit, authenticator, controllerManager, scheduler.
Set to null to disable logging entirely.
EOT
  type    = list(string)
  default = null
}

variable "eks_log_retention_days" {
  description = "CloudWatch log retention period in days for EKS cluster"
  type        = number
}

# ================================
# Important requirements - variables that must exists as a repo Secret
# ================================

# this is the arn that was created using the requirements folder
# which we then manually set as the secret: AWS_ROLE_TO_ASSUME in the TF github repo
variable "github_oidc_role_arn" {
  description = "ARN of the GitHub OIDC role used to deploy from GitHub Actions"
  type        = string
  sensitive = true
}

# ArgoCD github App credentials
# This is the installed ArgoCD Github Application: Application ID 
# This is created prior to running TF (manually) and set as a secret in the TF repository
# This is then used to create an AWS secret which will give ArgoCD access to the Github Repository
variable "argocd_app_id" {
  description = "ArgoCD github application ID"
  type        = string
  sensitive = true
}

# This is the installed ArgoCD Github Application: Installation ID 
# This is created prior to running TF (manually) and set as a secret in the TF repository
# This is then used to create an AWS secret which will give ArgoCD access to the Github Repository
variable "argocd_installation_id" {
  description = "ArgoCD github installation ID"
  type        = string
  sensitive = true
}

# This is the installed ArgoCD Github Application: Private Key base-64 encoded
# This is created prior to running TF (manually) and set as a secret in the TF repository
# This is then used to create an AWS secret which will give ArgoCD access to the Github Repository
variable "argocd_private_key_b64" {
  type      = string
  sensitive = true
  default   = ""
}

variable "github_oauth_client_id" {
  description = "GitHub OAuth App Client ID for ArgoCD authentication"
  type        = string
  sensitive   = true
}

variable "github_oauth_client_secret" {
  description = "GitHub OAuth App Client Secret for ArgoCD authentication"
  type        = string
  sensitive   = true
}
# ================================

variable "eks_user_access_map" {
  description = "Map of IAM users to be added to aws-auth with their usernames and groups"
  type = map(object({
    username = string
    groups   = list(string)
  }))
  default = {}
}

variable "eks_addons_namespace" {
  type        = string
  description = "Kubernetes namespace for Addons"
}

variable "aws_lb_controller_chart_version" {
  description = "Version of the AWS Load Balancer Controller Helm chart to deploy"
  type        = string
}

variable "external_dns_chart_version" {
  description = "Version of the External DNS Controller Helm chart to deploy"
  type        = string
}

variable "cluster_autoscaler_chart_version" {
  description = "Version of the Cluster Autoscaler Helm chart to deploy"
  type        = string
}

variable "metrics_server_chart_version" {
  description = "Version of the Metrics Server Helm chart to deploy"
  type        = string
}

variable "external_secrets_operator_chart_version" {
  description = "Version of the External secrets operator Controller Helm chart to deploy"
  type        = string
}

variable "frontend_service_account_name" {
  description = "Name of the frontend service account"
  type        = string
}

variable "frontend_service_namespace" {
  description = "Namespace where the frontend service account is deployed"
  type        = string
}

## ArgoCD
# ArgoCD Creation Control
variable "argocd_enabled" {
  description = "Enable ArgoCD deployment. Set to false for initial infrastructure deployment, true to create ArgoCD."
  type        = bool
  default     = false
  validation {
    condition     = can(var.argocd_enabled)
    error_message = "ArgoCD enabled must be a boolean value (true or false)."
  }
}

variable "argocd_chart_version" {
  type        = string
  description = "ArgoCD Helm chart version"
}

variable "argocd_namespace" {
  type        = string
  description = "Kubernetes namespace for ArgoCD"
  default     = "argocd"
}

variable "argocd_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the cluster endpoint"
  type        = list(string)
  default     = []
}

variable "argocd_base_domain_name" {
  type        = string
  description = "Base domain name for ArgoCD"
}

variable "argocd_app_of_apps_path" {
  description = "Path within the GitOps repository where ArgoCD should look for Application manifests."
  type        = string
  default     = "apps"
}

variable "argocd_app_of_apps_target_revision" {
  description = "Branch or Git reference in the GitOps repository that ArgoCD should track."
  type        = string
  default     = "main"
}

variable "argocd_aws_secret_key" {
  description = "Key used to name the argocd application's AWS secret (holds argocd's credentials for the gitops repo"
  type        = string
}

variable "ingress_controller_class" {
  type        = string
  description = "Ingress Controller Class Resource Name"
}

# Github Details
variable "github_org" {
  description = "GitHub organization"
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