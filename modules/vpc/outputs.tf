# modules/vpc/outputs.tf

output "private_subnet_ids" {
  value       = [for subnet in aws_subnet.private : subnet.id]
  description = "List of private subnet IDs"
}

output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}
