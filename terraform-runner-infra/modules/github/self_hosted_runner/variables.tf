# modules/github/self_hosted_runner/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where runner will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for runner placement"
  type        = list(string)
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name for Terraform"
  type        = string
}

variable "github_token" {
  description = "GitHub PAT with repo and admin:org permissions"
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name for kubectl configuration (from main project)"
  type        = string
}

# Instance Configuration
variable "instance_type" {
  description = "EC2 instance type for GitHub runner"
  type        = string
  default     = "t3.small"
}

variable "ami_id" {
  description = "AMI ID for GitHub runner (Ubuntu 22.04 recommended)"
  type        = string
  default     = null # Will use data source to find latest Ubuntu
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Size of root EBS volume in GB"
  type        = number
  default     = 30
}

# Scaling Configuration
variable "min_runners" {
  description = "Minimum number of runner instances"
  type        = number
  default     = 1
}

variable "max_runners" {
  description = "Maximum number of runner instances"
  type        = number
  default     = 2
}

variable "desired_runners" {
  description = "Desired number of runner instances"
  type        = number
  default     = 1
}

# Runner Configuration
variable "runner_labels" {
  description = "Labels to assign to GitHub runners"
  type        = list(string)
  default     = ["self-hosted", "terraform", "aws"]
}

# SSH Access
variable "enable_ssh_access" {
  description = "Enable SSH access to runner instances"
  type        = bool
  default     = false
  
  validation {
    condition = !var.enable_ssh_access || length(var.ssh_allowed_cidr_blocks) > 0
    error_message = "SSH allowed CIDR blocks must be specified when SSH access is enabled."
  }
}

variable "ssh_allowed_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = []
}

variable "runners_per_instance" {
  description = "Number of runner processes per EC2 instance"
  type        = number
  default     = 2
  
  validation {
    condition     = var.runners_per_instance >= 1 && var.runners_per_instance <= 5
    error_message = "Runners per instance must be between 1 and 5."
  }
}
