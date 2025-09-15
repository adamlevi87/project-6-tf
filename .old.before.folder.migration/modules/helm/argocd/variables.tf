# modules/helm/argocd/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "namespace" {
  type        = string
  description = "The Kubernetes namespace to install the Helm release into"
}

variable "alb_security_groups" {
  description = "Security groups for ALB (comma-separated)"
  type        = string
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

# ================================
# ArgoCD Server Configuration
# ================================
variable "server_memory_requests" {
  description = "ArgoCD server memory requests"
  type        = string
  default     = "256Mi"
}

variable "server_cpu_requests" {
  description = "ArgoCD server CPU requests"
  type        = string
  default     = "100m"
}

variable "server_memory_limits" {
  description = "ArgoCD server memory limits"
  type        = string
  default     = "512Mi"
}

variable "server_cpu_limits" {
  description = "ArgoCD server CPU limits"
  type        = string
  default     = "500m"
}

variable "server_metrics_enabled" {
  description = "Enable metrics for ArgoCD server"
  type        = bool
  default     = true
}

variable "server_metrics_port" {
  description = "ArgoCD server metrics port"
  type        = number
  default     = 8083
}

variable "server_metrics_port_name" {
  description = "ArgoCD server metrics port name"
  type        = string
  default     = "http-metrics"
}

variable "server_metrics_scrape_enabled" {
  description = "Enable Prometheus scraping for ArgoCD server"
  type        = string
  default     = "true"
}

variable "server_metrics_path" {
  description = "ArgoCD server metrics path"
  type        = string
  default     = "/metrics"
}

variable "server_metrics_labels" {
  description = "Labels for ArgoCD server metrics service"
  type        = map(string)
  default = {
    "app.kubernetes.io/component" = "server"
    "app.kubernetes.io/name"      = "argocd-server-metrics"
  }
}

# ================================
# ArgoCD Controller Configuration
# ================================
variable "controller_memory_requests" {
  description = "ArgoCD application controller memory requests"
  type        = string
  default     = "1Gi"
}

variable "controller_cpu_requests" {
  description = "ArgoCD application controller CPU requests"
  type        = string
  default     = "250m"
}

variable "controller_memory_limits" {
  description = "ArgoCD application controller memory limits"
  type        = string
  default     = "2Gi"
}

variable "controller_cpu_limits" {
  description = "ArgoCD application controller CPU limits"
  type        = string
  default     = "1000m"
}

variable "controller_metrics_enabled" {
  description = "Enable metrics for ArgoCD application controller"
  type        = bool
  default     = true
}

variable "controller_metrics_port" {
  description = "ArgoCD application controller metrics port"
  type        = number
  default     = 8082
}

variable "controller_metrics_port_name" {
  description = "ArgoCD application controller metrics port name"
  type        = string
  default     = "http-metrics"
}

variable "controller_metrics_scrape_enabled" {
  description = "Enable Prometheus scraping for ArgoCD application controller"
  type        = string
  default     = "true"
}

variable "controller_metrics_path" {
  description = "ArgoCD application controller metrics path"
  type        = string
  default     = "/metrics"
}

variable "controller_metrics_labels" {
  description = "Labels for ArgoCD application controller metrics service"
  type        = map(string)
  default = {
    "app.kubernetes.io/component" = "application-controller"
    "app.kubernetes.io/name"      = "argocd-application-controller-metrics"
  }
}

# ================================
# ArgoCD Repo Server Configuration
# ================================
variable "repo_server_memory_requests" {
  description = "ArgoCD repo server memory requests"
  type        = string
  default     = "256Mi"
}

variable "repo_server_cpu_requests" {
  description = "ArgoCD repo server CPU requests"
  type        = string
  default     = "100m"
}

variable "repo_server_memory_limits" {
  description = "ArgoCD repo server memory limits"
  type        = string
  default     = "512Mi"
}

variable "repo_server_cpu_limits" {
  description = "ArgoCD repo server CPU limits"
  type        = string
  default     = "500m"
}

variable "repo_server_metrics_enabled" {
  description = "Enable metrics for ArgoCD repo server"
  type        = bool
  default     = true
}

variable "repo_server_metrics_port" {
  description = "ArgoCD repo server metrics port"
  type        = number
  default     = 8084
}

variable "repo_server_metrics_port_name" {
  description = "ArgoCD repo server metrics port name"
  type        = string
  default     = "http-metrics"
}

variable "repo_server_metrics_scrape_enabled" {
  description = "Enable Prometheus scraping for ArgoCD repo server"
  type        = string
  default     = "true"
}

variable "repo_server_metrics_path" {
  description = "ArgoCD repo server metrics path"
  type        = string
  default     = "/metrics"
}

variable "repo_server_metrics_labels" {
  description = "Labels for ArgoCD repo server metrics service"
  type        = map(string)
  default = {
    "app.kubernetes.io/component" = "repo-server"
    "app.kubernetes.io/name"      = "argocd-repo-server-metrics"
  }
}

# ================================
# ArgoCD Dex Server Configuration
# ================================
variable "dex_memory_requests" {
  description = "ArgoCD dex server memory requests"
  type        = string
  default     = "64Mi"
}

variable "dex_cpu_requests" {
  description = "ArgoCD dex server CPU requests"
  type        = string
  default     = "50m"
}

variable "dex_memory_limits" {
  description = "ArgoCD dex server memory limits"
  type        = string
  default     = "128Mi"
}

variable "dex_cpu_limits" {
  description = "ArgoCD dex server CPU limits"
  type        = string
  default     = "100m"
}

variable "dex_metrics_enabled" {
  description = "Enable metrics for ArgoCD dex server"
  type        = bool
  default     = false
}

variable "dex_metrics_port" {
  description = "ArgoCD dex server metrics port"
  type        = number
  default     = 5558
}

variable "dex_metrics_port_name" {
  description = "ArgoCD dex server metrics port name"
  type        = string
  default     = "http-metrics"
}

variable "dex_metrics_scrape_enabled" {
  description = "Enable Prometheus scraping for ArgoCD dex server"
  type        = string
  default     = "true"
}

variable "dex_metrics_path" {
  description = "ArgoCD dex server metrics path"
  type        = string
  default     = "/metrics"
}

variable "dex_metrics_labels" {
  description = "Labels for ArgoCD dex server metrics service"
  type        = map(string)
  default = {
    "app.kubernetes.io/component" = "dex-server"
    "app.kubernetes.io/name"      = "argocd-dex-server-metrics"
  }
}
