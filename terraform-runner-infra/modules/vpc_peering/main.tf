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
  backend = "s3"
  config = {
    bucket = "${var.project_tag}-tf-state"
    key    = "${var.project_tag}/${var.environment}/main/terraform.tfstate"
    region = "${var.aws_region}"
  }
}

output "main_vpc_info" {
  description = "Main VPC information for runner infrastructure"
  value = {
    vpc_id                     = module.vpc.vpc_id
    vpc_cidr_block            = module.vpc.vpc_cidr_block
    private_subnet_ids        = module.vpc.private_subnet_ids
    private_route_table_ids   = module.vpc.private_route_table_ids
    availability_zones        = keys(local.private_subnet_cidrs)
  }
  sensitive = false
}

# Create VPC Peering Connection Request
resource "aws_vpc_peering_connection" "to_main" {
  vpc_id      = var.source_vpc_id
  peer_vpc_id = terraform_remote_state.main.outputs.main_vpc_info.vpc_id
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
  destination_cidr_block    = terraform_remote_state.main.outputs.main_vpc_info.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.to_main.id
  
  depends_on = [aws_vpc_peering_connection.to_main]
}
