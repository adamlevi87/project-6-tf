# terraform-main/modules/vpc/outputs.tf

output "private_subnet_ids" {
  value       = [for subnet in aws_subnet.private : subnet.id]
  description = "List of private subnet IDs"
}

output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}

output "vpc_cidr_block" {
  value       = aws_vpc.main.cidr_block
  description = "CIDR block of the VPC"
}

output "public_subnet_ids" {
  value       = concat(
    [for subnet in aws_subnet.public_primary : subnet.id],
    [for subnet in aws_subnet.public_additional : subnet.id]
  )
  description = "List of all public subnet IDs"
}

# Route table outputs for VPC peering
output "private_route_table_ids" {
  value       = [for rt in aws_route_table.private : rt.id]
  description = "List of private route table IDs"
}

output "public_route_table_ids" {
  value       = concat(
    [for rt in aws_route_table.public_primary : rt.id],
    [for rt in aws_route_table.public_additional : rt.id]
  )
  description = "List of all public route table IDs"
}

# Primary route table IDs (useful for specific targeting)
output "primary_public_route_table_ids" {
  value       = [for rt in aws_route_table.public_primary : rt.id]
  description = "List of primary public route table IDs"
}

output "additional_public_route_table_ids" {
  value       = [for rt in aws_route_table.public_additional : rt.id]
  description = "List of additional public route table IDs"
}
