# main/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "enable_lifecycle_policy" {
  description = "Enable or disable S3 bucket lifecycle policy"
  type        = bool
}

variable "ecr_repository_name" {
  description = "Base name prefix for all ECR repositories"
  type        = string
}

variable "ecr_repositories_applications" {
  description = "List of application names to create ECR repositories for"
  type        = list(string)
}

variable "domain_name" {
  type        = string
  description = "The root domain to configure (e.g., yourdomain.com)"
}

variable "subdomain_name" {
  type        = string
  description = "The subdomain for the app (e.g., chatbot)"
}

# EKS Cluster Configuration
variable "eks_kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "eks_api_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the cluster endpoint"
  type        = list(string)
  default     = []
}

# EKS Node Group Configuration
variable "eks_node_groups" {
  description = "Map of EKS node group configurations"
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
    condition = length(var.eks_node_groups) > 0
    error_message = "At least one node group must be defined."
  }
}

# EKS Logging Configuration
variable "cluster_enabled_log_types" {
  description = <<EOT
List of cluster log types to enable.
Available: api, audit, authenticator, controllerManager, scheduler.
Set to null to disable logging entirely.
EOT
  type    = list(string)
  default = null
}

variable "eks_log_retention_days" {
  description = "CloudWatch log retention period in days for EKS cluster"
  type        = number
}

# ================================
# Important requirements
# ================================

# this is the arn that was created using the requirements folder
# which we then set as the secret: AWS_ROLE_TO_ASSUME for the TF repo
variable "github_oidc_role_arn" {
  description = "ARN of the GitHub OIDC role used to deploy from GitHub Actions"
  type        = string
  sensitive = true
}

variable "eks_user_access_map" {
  description = "Map of IAM users to be added to aws-auth with their usernames and groups"
  type = map(object({
    username = string
    groups   = list(string)
  }))
  default = {}
}

variable "eks_addons_namespace" {
  type        = string
  description = "Kubernetes namespace for Addons"
}

variable "aws_lb_controller_chart_version" {
  description = "Version of the AWS Load Balancer Controller Helm chart to deploy"
  type        = string
}

variable "external_dns_chart_version" {
  description = "Version of the External DNS Controller Helm chart to deploy"
  type        = string
}

variable "metrics_server_chart_version" {
  description = "Version of the Metrics Server Helm chart to deploy"
  type        = string
}



