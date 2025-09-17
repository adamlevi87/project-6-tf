# # terraform-main/modules/vpc_peering/outputs.tf

output "vpc_peering_connection_id" {
  description = "ID of the VPC peering connection"
  #value       = aws_vpc_peering_connection.to_main.id
  #value       = length(aws_vpc_peering_connection.to_main) > 0 ? aws_vpc_peering_connection.to_main[0].id : null
  value       = try(aws_vpc_peering_connection.to_main.id, null)
}

# output "vpc_peering_connection_status" {
#   description = "Status of the VPC peering connection"
#   value       = aws_vpc_peering_connection.to_main.accept_status
# }

# output "peering_connection_info" {
#   description = "Complete peering connection information"
#   value = {
#     id               = aws_vpc_peering_connection.to_main.id
#     status           = aws_vpc_peering_connection.to_main.accept_status
#     source_vpc_id    = var.source_vpc_id
#     peer_vpc_id      = var.peer_vpc_id
#     peer_vpc_cidr    = var.peer_vpc_cidr
#   }
# }
