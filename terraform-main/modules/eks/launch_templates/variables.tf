# terraform-main/modules/eks/launch_templates/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
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

variable "node_security_group_ids" {
  description = "Map of node group names to their security group IDs"
  type        = map(string)
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster endpoint"
  type        = string
}

variable "cluster_ca" {
  description = "EKS cluster certificate authority data"
  type        = string
}

variable "cluster_cidr" {
  description = "EKS cluster service IPv4 CIDR"
  type        = string
}
