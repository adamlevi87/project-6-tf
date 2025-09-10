# modules/vpc-network/outputs.tf

output "private_subnet_ids" {
  value       = [for subnet in aws_subnet.private : subnet.id]
  description = "List of private subnet IDs"
}

output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}



# output "public_subnet_ids" {
#   value = concat(
#     [for subnet in aws_subnet.public_primary : subnet.id],
#     [for subnet in aws_subnet.public_additional : subnet.id]
#   )
#   description = "List of public subnet IDs"
# }

# # NAT gateways id, in single mode- only 1 nat - the primary nat
# # in real mode - the primary nat + the additional nats will be in the output
# output "nat_gateway_ids" {
#   value = merge(
#     var.nat_mode != "endpoints" ? { (local.primary_az) = aws_nat_gateway.nat_primary[0].id } : {},
#     var.nat_mode == "real" ? { for k, v in aws_nat_gateway.nat_additional : k => v.id } : {}
#   )
#   description = "Map of NAT gateway IDs by AZ"
# }

# output "nat_mode" {
#   value = var.nat_mode
#   description = "Current NAT mode: single (primary NAT only), real (NAT per AZ), or endpoints (no NATs)"
# }

# output "public_subnets" {
#   value = {
#     primary = {
#       for k, v in aws_subnet.public_primary : k => {
#         id = v.id
#         cidr = v.cidr_block
#         az = v.availability_zone
#       }
#     }
#     additional = {
#       for k, v in aws_subnet.public_additional : k => {
#         id = v.id
#         cidr = v.cidr_block
#         az = v.availability_zone
#       }
#     }
#   }
#   description = "All public subnets organized by type"
# }