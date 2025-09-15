# modules/vpc_peering/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

# Create VPC Peering Connection Request
resource "aws_vpc_peering_connection" "to_main" {
  vpc_id      = var.source_vpc_id
  peer_vpc_id = var.peer_vpc_id
  peer_region = var.peer_region
  auto_accept = false  # Will be accepted by the main project

  tags = {
    Name        = "${var.project_tag}-${var.environment}-to-main-peering"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "runner-to-main-vpc-peering"
    Side        = "requester"
  }
}

# Add route to main VPC through peering connection
resource "aws_route" "runner_to_main" {
  route_table_id            = var.source_route_table_id
  destination_cidr_block    = var.peer_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.to_main.id
  
  depends_on = [aws_vpc_peering_connection.to_main]
}

# Optional: Add route for public subnet if needed
resource "aws_route" "runner_public_to_main" {
  count = var.source_public_route_table_id != null ? 1 : 0
  
  route_table_id            = var.source_public_route_table_id
  destination_cidr_block    = var.peer_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.to_main.id
  
  depends_on = [aws_vpc_peering_connection.to_main]
}
