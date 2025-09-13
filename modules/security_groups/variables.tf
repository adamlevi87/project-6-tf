# modules/security_groups/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where RDS will be deployed"
  type        = string
}

variable "argocd_allowed_cidr_blocks" {
  type        = list(string)
  description = "List of CIDR blocks allowed to access the ALB-argoCD"
}

# Node Group Configuration
variable "node_groups" {
  description = "Map of node group configurations"
  type = map(object({
    instance_type     = string
    ami_id           = string
    desired_capacity = number
    max_capacity     = number
    min_capacity     = number
    labels           = map(string)
  }))
  
  validation {
    condition = length(var.node_groups) > 0
    error_message = "At least one node group must be defined."
  }
}

variable "eks_api_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the cluster endpoint"
  type        = list(string)
  default     = []
}

variable "cluster_security_group_id" {
  description = "EKS cluster security group ID"
  type        = string
}

variable "prometheus_allowed_cidr_blocks" {
  type        = list(string)
  description = "List of CIDR blocks allowed to access Prometheus/Grafana"
}

variable "grafana_allowed_cidr_blocks" {
  type        = list(string)
  description = "List of CIDR blocks allowed to access Grafana"
}
