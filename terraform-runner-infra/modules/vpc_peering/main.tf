# modules/vpc_peering/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

data "terraform_remote_state" "main" {
  count = 0
  backend = "s3"
  config = {
    bucket = "${var.project_tag}-tf-state"
    key    = "${var.project_tag}/${var.environment}/main/terraform.tfstate"
    region = "${var.aws_region}"
  }
}

# Create VPC Peering Connection Request
resource "aws_vpc_peering_connection" "to_main" {
  count = length(data.terraform_remote_state.main) > 0 ? 1 : 0

  vpc_id      = var.source_vpc_id
  peer_vpc_id = data.terraform_remote_state.main[0].outputs.main_vpc_info.vpc_id  # Note the [0]
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
  count = length(data.terraform_remote_state.main) > 0 ? 1 : 0

  route_table_id            = var.source_route_table_id
  destination_cidr_block = data.terraform_remote_state.main[0].outputs.main_vpc_info.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.to_main.id
  
  depends_on = [aws_vpc_peering_connection.to_main]
}
