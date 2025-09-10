# modules/aws_auth_config/variables.tf

variable "aws_provider_version" {
  description = "AWS provider version"
  type        = string
}

variable "kubernetes_provider_version" {
  description = "Kubernetes provider version"
  type        = string
}

variable "map_roles" {
  description = "List of IAM roles to map to Kubernetes RBAC"
  type        = list(any)
  default     = []
}

variable "eks_user_access_map" {
  description = "Map of IAM users and their RBAC group mappings"
  type = map(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = {}
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}
