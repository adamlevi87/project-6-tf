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

# data "terraform_remote_state" "runner_infra" {
#   backend = "s3"
#   config = {
#     bucket = "${var.project_tag}-tf-state"
#     key    = "${var.project_tag}-tf/${var.environment}/runner-infra/terraform.tfstate"
#     region = "${var.aws_region}"
#   }
# }

resource "null_resource" "validate_peering_outputs" {
  #count = var.initialize_run ? 0 : 1
  
  provisioner "local-exec" {
    command = <<-EOF
      if [ "${var.peering_connection_id}" = "fake-placeholder" ]; then
        echo "ERROR: Required peering_connection_id missing"
        exit 1
      fi
      if [ "${var.runner_vpc_cidr}" = "10.255.255.0/24" ]; then
        echo "ERROR: Required runner_vpc_cidr missing" 
        exit 1
      fi
      echo "✅ All peering outputs validated"
    EOF
  }
}

locals {
  #has_peering_request = length(data.aws_vpc_peering_connections.runner_requests.ids) > 0
  #peering_connection_id = local.has_peering_request ? data.aws_vpc_peering_connections.runner_requests.ids[0] : ""
  
  #peering_accepter = aws_vpc_peering_connection_accepter.runner_peering
}



resource "aws_vpc_peering_connection_accepter" "main" {
  #count = var.initialize_run ? 0 : 1
  
  vpc_peering_connection_id = var.peering_connection_id
  auto_accept               = true

  tags = {
    Name        = "${var.project_tag}-${var.environment}-accept-runner-peering"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "accept-runner-vpc-peering"
    Side        = "accepter"
  }

  depends_on = [null_resource.validate_peering_outputs]
}

# # Accept the peering connection from runner infrastructure
# resource "aws_vpc_peering_connection_accepter" "runner_peering" {
#   count = local.has_peering_request ? 1 : 0
  
#   #vpc_peering_connection_id = data.aws_vpc_peering_connections.runner_requests.ids[0]
#   vpc_peering_connection_id = data.terraform_remote_state.runner_infra.outputs.vpc_peering_connection_id
#   auto_accept              = true

#   tags = {
#     Name        = "${var.project_tag}-${var.environment}-accept-runner-peering"
#     Project     = var.project_tag
#     Environment = var.environment
#     Purpose     = "accept-runner-vpc-peering"
#     Side        = "accepter"
#   }
# }

resource "aws_route" "main_to_runner_private" {
  #count = var.initialize_run ? 0 : length(var.private_route_table_ids)
  count = length(var.private_route_table_ids)
  
  route_table_id            = var.private_route_table_ids[count.index]
  destination_cidr_block    = var.runner_vpc_cidr  # No try needed!
  vpc_peering_connection_id = var.peering_connection_id

  depends_on = [aws_vpc_peering_connection_accepter.main]
}

# # Add routes to runner VPC from main VPC private subnets
# resource "aws_route" "main_to_runner_private" {
#   #for_each = local.has_peering_request ? toset(var.private_route_table_ids) : []
#   for_each = toset(var.private_route_table_ids)
  
#   route_table_id            = each.value
#   #destination_cidr_block    = var.runner_vpc_cidr
#   destination_cidr_block    = data.terraform_remote_state.runner_infra.outputs.vpc_cidr_block
#   #vpc_peering_connection_id = local.peering_connection_id
#   vpc_peering_connection_id = data.terraform_remote_state.runner_infra.outputs.vpc_peering_connection_id
# }
