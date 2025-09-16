# terraform-main/modules/vpc_peering_acceptance/outputs.tf

# output "peering_connection_id" {
#   description = "ID of the accepted peering connection"
#   value       = length(local.peering_accepter) > 0 ? local.peering_accepter[0].vpc_peering_connection_id : ""
# }

# output "peering_connection_status" {
#   description = "Status of the peering connection"
#   value       = length(local.peering_accepter) > 0 ? local.peering_accepter[0].accept_status : "not-found"
# }

# output "accepted_connection_info" {
#   description = "Information about the accepted peering connection"
#   value = length(local.peering_accepter) > 0 ? {
#     id               = local.peering_accepter[0].vpc_peering_connection_id
#     status           = local.peering_accepter[0].accept_status
#     accepter_vpc_id  = var.vpc_id
#     runner_vpc_cidr  = var.runner_vpc_cidr
#     routes_created   = length(aws_route.main_to_runner_private)
#   } : {}
# }

# Output main VPC information for runner infrastructure to use
output "main_vpc_info" {
  description = "Main VPC information for runner infrastructure"
  value = {
    private_route_table_ids = var.private_route_table_ids
  }
}

# output "peering_connection_id" {
#   description = "VPC peering connection ID"
#   value       = var.initialize_run ? null : try(aws_vpc_peering_connection_accepter.main[0].vpc_peering_connection_id, null)
# }

# output "peering_connection_status" {
#   description = "VPC peering connection status"  
#   value       = var.initialize_run ? "not-initialized" : try(aws_vpc_peering_connection_accepter.main[0].accept_status, null)
# }

# output "routes_created" {
#   description = "Number of routes created for peering"
#   value       = var.initialize_run ? 0 : (length(aws_route.main_to_runner_private) + length(aws_route.main_to_runner_public))
# }
