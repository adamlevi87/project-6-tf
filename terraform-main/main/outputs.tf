# Add these outputs to terraform-main/main/outputs.tf

# ================================
# VPC Information (for runner infrastructure consumption)
# ================================
output "main_vpc_info" {
  description = "Main VPC information for runner infrastructure"
  value = {
    vpc_id                     = module.vpc.vpc_id
    vpc_cidr_block            = module.vpc.vpc_cidr_block
    private_subnet_ids        = module.vpc.private_subnet_ids
    private_route_table_ids   = module.vpc.private_route_table_ids
    availability_zones        = keys(local.private_subnet_cidrs)
    region                    = var.aws_region
  }
  sensitive = false
}

# ================================
# EKS Cluster Information (for runner kubectl configuration)
# ================================
output "eks_cluster_info" {
  description = "EKS cluster information for runner configuration"
  value = {
    cluster_name     = module.eks.cluster_name
    cluster_endpoint = module.eks.cluster_endpoint
    cluster_private_endpoint = module.eks.cluster_endpoint
    cluster_ca       = module.eks.cluster_ca
    cluster_region   = var.aws_region
  }
  sensitive = false
}

# # ================================
# # VPC Peering Information
# # ================================
# output "vpc_peering_info" {
#   description = "VPC peering connection information"
#   value = {
#     peering_connection_id     = module.vpc_peering_acceptance.peering_connection_id
#     peering_connection_status = module.vpc_peering_acceptance.peering_connection_status
#     accepted_connection_info  = module.vpc_peering_acceptance.accepted_connection_info
#   }
#   sensitive = false
# }

