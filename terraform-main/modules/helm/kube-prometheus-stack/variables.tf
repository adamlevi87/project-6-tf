# terraform-main/modules/helm/kube-prometheus-stack/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "release_name" {
  description = "Helm release name"
  type        = string
}

variable "chart_version" {
  description = "Helm chart version"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for monitoring stack"
  type        = string
}

variable "domain_name" {
  description = "Base domain name"
  type        = string
}

variable "grafana_domain" {
  description = "Grafana domain name"
  type        = string
}

variable "prometheus_domain" {
  description = "Prometheus domain name"
  type        = string
}

variable "ingress_controller_class" {
  description = "Ingress controller class"
  type        = string
}

variable "alb_group_name" {
  description = "ALB group name for shared load balancer"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
}

variable "prometheus_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Prometheus"
  type        = list(string)
}

variable "grafana_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Grafana"
  type        = list(string)
}

variable "alb_security_groups" {
  description = "Security groups for ALB (comma-separated)"
  type        = string
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

# Storage configuration
variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
}

# Prometheus configuration
variable "prometheus_retention" {
  description = "Prometheus data retention period"
  type        = string
}

variable "prometheus_retention_size" {
  description = "Prometheus maximum storage size"
  type        = string
}

variable "prometheus_storage_size" {
  description = "Prometheus storage volume size"
  type        = string
}

variable "prometheus_cpu_requests" {
  description = "Prometheus CPU requests"
  type        = string
}

variable "prometheus_memory_requests" {
  description = "Prometheus memory requests"
  type        = string
}

variable "prometheus_cpu_limits" {
  description = "Prometheus CPU limits"
  type        = string
}

variable "prometheus_memory_limits" {
  description = "Prometheus memory limits"
  type        = string
}



# Grafana configuration
variable "grafana_storage_size" {
  description = "Grafana storage volume size"
  type        = string
}

variable "grafana_cpu_requests" {
  description = "Grafana CPU requests"
  type        = string
}

variable "grafana_memory_requests" {
  description = "Grafana memory requests"
  type        = string
}

variable "grafana_cpu_limits" {
  description = "Grafana CPU limits"
  type        = string
}

variable "grafana_memory_limits" {
  description = "Grafana memory limits"
  type        = string
}

# AlertManager configuration
variable "alertmanager_storage_size" {
  description = "AlertManager storage volume size"
  type        = string
}

variable "alertmanager_cpu_requests" {
  description = "AlertManager CPU requests"
  type        = string
}

variable "alertmanager_memory_requests" {
  description = "AlertManager memory requests"
  type        = string
}

variable "alertmanager_cpu_limits" {
  description = "AlertManager CPU limits"
  type        = string
}

variable "alertmanager_memory_limits" {
  description = "AlertManager memory limits"
  type        = string
}
