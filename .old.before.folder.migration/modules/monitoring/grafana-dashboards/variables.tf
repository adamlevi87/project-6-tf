# modules/monitoring/grafana-dashboards/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "monitoring_namespace" {
  description = "Namespace where Grafana is deployed"
  type        = string
}

variable "prometheus_datasource_name" {
  description = "Name of the Prometheus datasource in Grafana"
  type        = string
}

variable "enable_aws_lbc_dashboard" {
  description = "Enable AWS Load Balancer Controller dashboard"
  type        = bool
  default     = true
}
