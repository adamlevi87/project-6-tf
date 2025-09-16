# terraform-runner-infra/environments/dev/terraform.tfvars

# ================================
# General Configuration
# ================================
project_tag = "project-6"
environment = "dev"
aws_region  = "us-east-1"
initialize_run = false
# ================================
# VPC Configuration
# ================================
# Use different CIDR from main project to avoid conflicts
vpc_cidr_block = "10.1.0.0/16"  # Main project uses 10.0.0.0/16
# Enabling VPC peering to the main's VPC
enable_vpc_peering = true
# main_vpc_id = ""
# main_vpc_cidr = "10.0.0.0/16"
# ================================
# GitHub Configuration
# ================================
github_org              = "adamlevi87"
github_terraform_repo   = "project-6-tf"

# GitHub token will be provided via environment variable:
# export TF_VAR_github_token="your-github-pat-token"
# Or via terraform.tfvars.local (not committed to git)

# ================================
# Runner Instance Configuration
# ================================
runner_instance_type     = "t3.small"    # Free tier friendly option
runner_ami_id           = "ami-0bbdd8c17ed981ef9"           # Canonical ubuntu 22.04
key_pair_name           = "temp-manual"           # Set if you want SSH access
runner_root_volume_size = 30             # GB - enough for Terraform ops
runners_per_instance = 2
# ================================
# Runner Scaling Configuration
# ================================
min_runners     = 1
max_runners     = 2
desired_runners = 1

# ================================
# Runner Configuration
# ================================
runner_labels = [
  "self-hosted",
  "terraform", 
  "aws",
  "runner-infra",
  "project-6",
  "dev"
]

# Initially empty - will be updated after main project creates EKS cluster
cluster_name = ""

# ================================
# SSH Access Configuration
# ================================
enable_ssh_access = true  # Set to true if you need to debug runner instances
ssh_allowed_cidr_blocks = ["85.65.159.200/32"]  # Uncomment and add your IP if enabling SSH

