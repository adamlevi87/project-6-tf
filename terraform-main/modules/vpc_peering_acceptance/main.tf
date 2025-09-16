# terraform-main/modules/vpc_peering_acceptance/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

# # Data source to find pending peering connection requests
# data "aws_vpc_peering_connections" "runner_requests" {
#   filter {
#     name   = "accepter-vpc-info.vpc-id"
#     values = [var.vpc_id]
#   }
  
#   filter {
#     name   = "status-code"
#     values = ["pending-acceptance"]
#   }
  
#   filter {
#     name   = "tag:Project"
#     values = [var.project_tag]
#   }
  
#   filter {
#     name   = "tag:Environment" 
#     values = [var.environment]
#   }
# }

data "terraform_remote_state" "runner_infra" {
  backend = "s3"
  config = {
    bucket = "${var.project_tag}-tf-state"
    key    = "${var.project_tag}-tf/${var.environment}/runner-infra/terraform.tfstate"
    region = "${var.aws_region}"
  }
}

locals {
  #has_peering_request = length(data.aws_vpc_peering_connections.runner_requests.ids) > 0
  #peering_connection_id = local.has_peering_request ? data.aws_vpc_peering_connections.runner_requests.ids[0] : ""
  
  #peering_accepter = aws_vpc_peering_connection_accepter.runner_peering
}

# Accept the peering connection from runner infrastructure
resource "aws_vpc_peering_connection_accepter" "runner_peering" {
  #count = local.has_peering_request ? 1 : 0
  
  #vpc_peering_connection_id = data.aws_vpc_peering_connections.runner_requests.ids[0]
  vpc_peering_connection_id = data.terraform_remote_state.runner_infra.outputs.peering_connection_id
  auto_accept              = true

  tags = {
    Name        = "${var.project_tag}-${var.environment}-accept-runner-peering"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "accept-runner-vpc-peering"
    Side        = "accepter"
  }
}

# Add routes to runner VPC from main VPC private subnets
resource "aws_route" "main_to_runner_private" {
  #for_each = local.has_peering_request ? toset(var.private_route_table_ids) : []
  for_each = toset(var.private_route_table_ids)
  
  route_table_id            = each.value
  #destination_cidr_block    = var.runner_vpc_cidr
  destination_cidr_block    = data.terraform_remote_state.runner_infra.outputs.vpc_cidr_block
  #vpc_peering_connection_id = local.peering_connection_id
  vpc_peering_connection_id = data.terraform_remote_state.runner_infra.outputs.peering_connection_id
}
