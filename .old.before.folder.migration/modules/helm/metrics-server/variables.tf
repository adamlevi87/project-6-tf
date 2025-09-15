# modules/helm/metrics-server/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "release_name" {
  description = "The Helm release name"
  type        = string
  default     = "metrics-server"
}

variable "chart_version" {
  description = "The version of the metrics-server Helm chart"
  type        = string
}

variable "namespace" {
  description = "The Kubernetes namespace to install the Helm release into"
  type        = string
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account for metrics-server"
  type        = string
}

variable "cpu_requests" {
  description = "CPU requests for metrics-server"
  type        = string
  default     = "100m"
}

variable "memory_requests" {
  description = "Memory requests for metrics-server"
  type        = string
  default     = "200Mi"
}

variable "cpu_limits" {
  description = "CPU limits for metrics-server"
  type        = string
  default     = "1000m"
}

variable "memory_limits" {
  description = "Memory limits for metrics-server"
  type        = string
  default     = "1000Mi"
}
