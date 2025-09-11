# modules/eks/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "ecr_repository_arns" {
  description = "Map of app name to ECR repository ARNs"
  type = map(string)
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
    taints           = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
  
  validation {
    condition = length(var.node_groups) > 0
    error_message = "At least one node group must be defined."
  }
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

# Logging
variable "cluster_log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
  validation {
    condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.cluster_log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS cluster"
  type        = list(string)
}

variable "eks_api_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the cluster endpoint"
  type        = list(string)
  default     = []
}

variable "cluster_enabled_log_types" {
  description = "List of cluster log types to enable. Available options: api, audit, authenticator, controllerManager, scheduler"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID where RDS will be deployed"
  type        = string
}

variable "node_security_group_ids" {
  description = "Map of node group names to their security group IDs"
  type        = map(string)
}
