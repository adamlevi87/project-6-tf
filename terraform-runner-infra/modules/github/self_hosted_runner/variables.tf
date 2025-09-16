# terraform-main/modules/github/self_hosted_runner/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "initialize_run" {
  description = "Whether this is an initialization run (true = deploy basics only, false = deploy everything)"
  type        = bool
}

variable "vpc_id" {
  description = "VPC ID where runner will be deployed"
  type        = string
}

# variable "runner_ami_id" {
#   description = "AMI ID for GitHub runner (if null, uses latest Ubuntu 22.04)"
#   type        = string
# }


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

# variable "cluster_name" {
#   description = "EKS cluster name for kubectl configuration (from main project)"
#   type        = string
# }

variable "instance_type" {
  description = "EC2 instance type for GitHub runner"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for GitHub runner (Ubuntu 22.04 recommended)"
  type        = string
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
}

variable "root_volume_size" {
  description = "Size of root EBS volume in GB"
  type        = number
}

variable "min_runners" {
  description = "Minimum number of runner instances"
  type        = number
}

variable "max_runners" {
  description = "Maximum number of runner instances"
  type        = number
}

variable "desired_runners" {
  description = "Desired number of runner instances"
  type        = number
}

variable "runner_labels" {
  description = "Labels to assign to GitHub runners"
  type        = list(string)
}

variable "runners_per_instance" {
  description = "Number of runner processes per EC2 instance"
  type        = number
}

variable "enable_ssh_access" {
  description = "Enable SSH access to runner instances"
  type        = bool
}

variable "ssh_allowed_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
}
