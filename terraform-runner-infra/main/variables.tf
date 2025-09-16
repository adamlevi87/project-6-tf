# terraform-runner-infra/main/variables.tf

# ================================
# General Configuration
# ================================
variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "initialize_run" {
  description = "Whether this is an initialization run (true = deploy basics only, false = deploy everything)"
  type        = bool
}

# ================================
# VPC Configuration
# ================================
variable "vpc_cidr_block" {
  description = "CIDR block for the runner VPC"
  type        = string
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr_block, 0))
    error_message = "VPC CIDR block must be a valid IPv4 CIDR."
  }
}

# ================================
# VPC Peering Configuration
# ================================
# variable "main_vpc_id" {
#   description = "VPC ID of the main project (for peering)"
#   type        = string
# }

# variable "main_vpc_cidr" {
#   description = "CIDR block of the main project VPC (for peering routes)"
#   type        = string
# }

variable "enable_vpc_peering" {
  description = "Enable VPC peering to main project VPC"
  type        = bool
}

# ================================
# GitHub Configuration
# ================================
variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "github_terraform_repo" {
  description = "GitHub repository name for the terraform project"
  type        = string
}

variable "github_token" {
  description = "GitHub Personal Access Token with TF repo permissions"
  type        = string
  sensitive   = true
}

# ================================
# Runner Instance Configuration
# ================================
variable "runner_instance_type" {
  description = "EC2 instance type for GitHub runner"
  type        = string
  
  validation {
    condition = contains([
      "t3.micro", "t3.small", "t3.medium", "t3.large",
      "t3a.micro", "t3a.small", "t3a.medium", "t3a.large"
    ], var.runner_instance_type)
    error_message = "Instance type must be a valid t3 or t3a instance type."
  }
}

variable "runner_ami_id" {
  description = "AMI ID for GitHub runner (if null, uses latest Ubuntu 22.04)"
  type        = string
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for SSH access to runner instances"
  type        = string
}

variable "runner_root_volume_size" {
  description = "Size of runner root EBS volume in GB"
  type        = number
  
  validation {
    condition     = var.runner_root_volume_size >= 20 && var.runner_root_volume_size <= 100
    error_message = "Root volume size must be between 20 and 100 GB."
  }
}

# ================================
# Runner Scaling Configuration
# ================================
variable "min_runners" {
  description = "Minimum number of runner instances"
  type        = number
  
  validation {
    condition     = var.min_runners >= 0 && var.min_runners <= 5
    error_message = "Minimum runners must be between 0 and 5."
  }
}

variable "max_runners" {
  description = "Maximum number of runner instances"
  type        = number
  
  validation {
    condition     = var.max_runners >= 1 && var.max_runners <= 10
    error_message = "Maximum runners must be between 1 and 10."
  }
}

variable "desired_runners" {
  description = "Desired number of runner instances"
  type        = number
  
  validation {
    condition     = var.desired_runners >= 0 && var.desired_runners <= 5
    error_message = "Desired runners must be between 0 and 5."
  }
}

# ================================
# Runner Configuration
# ================================
variable "runner_labels" {
  description = "Labels to assign to GitHub runners"
  type        = list(string)
  
  validation {
    condition     = length(var.runner_labels) > 0
    error_message = "At least one runner label must be specified."
  }
}

variable "runners_per_instance" {
  description = "Number of runner processes per EC2 instance"
  type        = number
  
  validation {
    condition     = var.runners_per_instance >= 1 && var.runners_per_instance <= 5
    error_message = "Runners per instance must be between 1 and 5."
  }
}

variable "cluster_name" {
  description = "EKS cluster name from main project (for kubectl configuration)"
  type        = string
}

# ================================
# SSH Access Configuration
# ================================
variable "enable_ssh_access" {
  description = "Enable SSH access to runner instances"
  type        = bool
  
  validation {
    condition = !var.enable_ssh_access || length(var.ssh_allowed_cidr_blocks) > 0
    error_message = "SSH allowed CIDR blocks must be specified when SSH access is enabled."
  }
}

variable "ssh_allowed_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access to runner instances"
  type        = list(string)
  
  validation {
    condition = alltrue([
      for cidr in var.ssh_allowed_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "All SSH allowed CIDR blocks must be valid IPv4 CIDRs."
  }
}
