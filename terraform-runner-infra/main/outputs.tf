# # terraform-runner-infra/main/outputs.tf

# # ================================
# # VPC Outputs (for main project to consume via remote state)
# # ================================
# output "vpc_id" {
#   description = "ID of the runner VPC"
#   value       = module.vpc.vpc_id
# }

output "vpc_cidr_block" {
  description = "CIDR block of the runner VPC"
  value       = module.vpc.vpc_cidr_block
}

# ================================
# VPC Peering Outputs
# ================================
output "vpc_peering_connection_id" {
  description = "ID of the VPC peering connection (if created)"
  value       =  try(module.vpc_peering.vpc_peering_connection_id, null)
  #value       =  length(module.vpc_peering) > 0 ? module.vpc_peering[0].vpc_peering_connection_id : null
  #value       = var.enable_vpc_peering && var.main_vpc_id != "" ? module.vpc_peering[0].vpc_peering_connection_id : null
  #value       = module.vpc_peering.vpc_peering_connection_id
}

output "runner_instance_role_arn" {
  description = "IAM role ARN for GitHub runner instances"
  value       = var.initialize_run ? null : module.github_runner.runner_instance_role_arn
}


# output "private_subnet_ids" {
#   description = "List of private subnet IDs"
#   value       = module.vpc.private_subnet_ids
# }

# output "public_subnet_ids" {
#   description = "List of public subnet IDs"
#   value       = module.vpc.public_subnet_ids
# }

# output "private_subnet_id" {
#   description = "ID of the single private subnet"
#   value       = module.vpc.private_subnet_id
# }

# output "public_subnet_id" {
#   description = "ID of the single public subnet" 
#   value       = module.vpc.public_subnet_id
# }

# output "availability_zone" {
#   description = "Availability zone used for the runner infrastructure"
#   value       = module.vpc.availability_zone
# }

# output "internet_gateway_id" {
#   description = "ID of the Internet Gateway"
#   value       = module.vpc.internet_gateway_id
# }

# output "nat_gateway_id" {
#   description = "ID of the NAT Gateway"
#   value       = module.vpc.nat_gateway_id
# }

# # ================================
# # GitHub Runner Outputs
# # ================================
# output "runner_security_group_id" {
#   description = "Security group ID for GitHub runners"
#   value       = module.github_runner.runner_security_group_id
# }

# output "runner_instance_role_arn" {
#   description = "IAM role ARN for GitHub runner instances"
#   value       = module.github_runner.runner_instance_role_arn
# }

# output "runner_autoscaling_group_name" {
#   description = "Auto Scaling Group name for GitHub runners"
#   value       = module.github_runner.runner_autoscaling_group_name
# }

# output "runner_autoscaling_group_arn" {
#   description = "Auto Scaling Group ARN for GitHub runners"  
#   value       = module.github_runner.runner_autoscaling_group_arn
# }

# output "runner_labels" {
#   description = "Labels assigned to GitHub runners"
#   value       = module.github_runner.runner_labels
# }

# # ================================
# # General Information
# # ================================
# output "project_info" {
#   description = "Project information"
#   value = {
#     project_tag = var.project_tag
#     environment = var.environment
#     aws_region  = var.aws_region
#   }
# }

# output "github_info" {
#   description = "GitHub configuration information (non-sensitive)"
#   value = {
#     github_org  = var.github_org
#     github_repo = var.github_terraform_repo
#     runner_labels = var.runner_labels
#   }
#   sensitive = false
# }

# output "vpc_peering_status" {
#   description = "Status of the VPC peering connection"
#   value       = var.enable_vpc_peering && var.main_vpc_id != "" ? module.vpc_peering[0].vpc_peering_connection_status : "not-created"
# }

# output "peering_info" {
#   description = "VPC peering connection information"
#   value = var.enable_vpc_peering && var.main_vpc_id != "" ? {
#     connection_id     = module.vpc_peering[0].vpc_peering_connection_id
#     status           = module.vpc_peering[0].vpc_peering_connection_status
#     runner_vpc_id    = module.vpc.vpc_id
#     runner_vpc_cidr  = module.vpc.vpc_cidr_block
#     main_vpc_id      = var.main_vpc_id
#     main_vpc_cidr    = var.main_vpc_cidr
#   } : null
# }
