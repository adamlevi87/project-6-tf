# modules/monitoring/service-monitors/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "monitoring_namespace" {
  description = "Namespace where Prometheus operator is deployed"
  type        = string
}

variable "argocd_namespace" {
  description = "Namespace where ArgoCD is deployed"
  type        = string
}

variable "aws_lb_controller_namespace" {
  description = "Namespace where AWS Load Balancer Controller is deployed"
  type        = string
}

variable "enable_dex_metrics" {
  description = "Enable Dex server metrics monitoring"
  type        = bool
  default     = false
}
