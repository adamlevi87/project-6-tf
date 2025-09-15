# terraform-main/modules/eks/node_groups/variables.tf

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
  type = list(string)
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

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS cluster"
  type        = list(string)
}

variable "launch_template_ids" {
  description = "Map of node group names to their launch template IDs"
  type        = map(string)
}
