# terraform-main/modules/vpc_peering/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

# data "terraform_remote_state" "main" {
#   backend = "s3"
#   config = {
#     bucket = "${var.project_tag}-tf-state"
#     key    = "${var.project_tag}-tf/${var.environment}/main/terraform.tfstate"
#     region = "${var.aws_region}"
#   }
# }
data "terraform_remote_state" "main" {
  #count = var.initialize_run ? 0 : 1
  backend = "s3"
  config = {
    bucket = "${var.project_tag}-tf-state"
    key    = "${var.project_tag}-tf/${var.environment}/main/terraform.tfstate"
    region = "${var.aws_region}"
  }
}

resource "null_resource" "validate_outputs_or_fail" {
  #count = var.initialize_run ? 0 : 1

  provisioner "local-exec" {
    command = <<-EOF
      # Check all required outputs for VPC peering
      VPC_ID="${try(data.terraform_remote_state.main.outputs.main_vpc_info.vpc_id, "")}"
      REGION="${try(data.terraform_remote_state.main.outputs.main_vpc_info.region, "")}"
      VPC_CIDR="${try(data.terraform_remote_state.main.outputs.main_vpc_info.vpc_cidr_block, "")}"
      
      if [ -z "$VPC_ID" ] || [ -z "$VPC_CIDR" ] || [ -z "$REGION" ]; then
        echo "ERROR: Required outputs missing from main terraform state:"
        echo "  VPC ID: $VPC_ID"
        echo "  VPC CIDR: $VPC_CIDR" 
        echo "  Region: $REGION"
        echo "Cannot proceed with VPC peering - main infrastructure outputs incomplete"
        echo "Run 'terraform apply' on main infrastructure first"
        exit 1
      fi
      
      echo "Validation passed - all required outputs present"
      echo "VPC ID: $VPC_ID"
      echo "VPC CIDR: $VPC_CIDR"
      echo "Region: $REGION"
    EOF
  }
}

# # Create VPC Peering Connection Request
# resource "aws_vpc_peering_connection" "to_main" {
#   vpc_id      = var.source_vpc_id
#   peer_vpc_id = data.terraform_remote_state.main.outputs.main_vpc_info.vpc_id
#   peer_region = data.terraform_remote_state.main.outputs.main_vpc_info.region
#   auto_accept = false  # Will be accepted by the main project
  
#   tags = {
#     Name        = "${var.project_tag}-${var.environment}-to-main-peering"
#     Project     = var.project_tag
#     Environment = var.environment
#     Purpose     = "runner-to-main-vpc-peering"
#     Side        = "requester"
#   }
# }

# Create VPC Peering Connection Request
resource "aws_vpc_peering_connection" "to_main" {
  #count = length(data.terraform_remote_state.main) > 0 ? 1 : 0

  vpc_id      = var.source_vpc_id
  #peer_vpc_id = length(data.terraform_remote_state.main) > 0 ? data.terraform_remote_state.main[0].outputs.vpc_id : null
  #peer_vpc_id = length(data.terraform_remote_state.main) > 0 ? data.terraform_remote_state.main[0].outputs.vpc_id : null
  peer_vpc_id = try(data.terraform_remote_state.main.outputs.main_vpc_info.vpc_id, "fake-id")  # fake-id Prevents validation error
  peer_region = try(data.terraform_remote_state.main.outputs.main_vpc_info.region, "fake-region") # fake-region fake region that will never be applied
  #peer_region = length(data.terraform_remote_state.main) > 0 ? data.terraform_remote_state.main[0].outputs.main_vpc_info.region : null
  #peer_region = var.peer_region
  auto_accept = false  # Will be accepted by the main project

  tags = {
    Name        = "${var.project_tag}-${var.environment}-to-main-peering"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "runner-to-main-vpc-peering"
    Side        = "requester"
  }

  depends_on = [null_resource.validate_outputs_or_fail]
}

# # Add route to main VPC through peering connection
# resource "aws_route" "runner_to_main" {
#   route_table_id            = var.source_route_table_id
#   destination_cidr_block    = data.terraform_remote_state.main.outputs.main_vpc_info.vpc_cidr_block
#   vpc_peering_connection_id = aws_vpc_peering_connection.to_main.id
# }

# Add route to main VPC through peering connection
resource "aws_route" "runner_to_main" {
  count = length(data.terraform_remote_state.main) > 0 ? 1 : 0

  route_table_id            = var.source_route_table_id
  destination_cidr_block = try(data.terraform_remote_state.main.outputs.main_vpc_info.vpc_cidr_block, "10.255.255.0/24") # 10.255.255.0 - fake cidr will never be applied
  vpc_peering_connection_id = try(aws_vpc_peering_connection.to_main.id, "pcx-fakeid12345") # pcx-fakeid12345 - fake id will never be applied
  #vpc_peering_connection_id = try(aws_vpc_peering_connection.to_main[0].id, "pcx-fakeid12345") # pcx-fakeid12345 - fake id will never be applied

  #destination_cidr_block = length(data.terraform_remote_state.main) > 0 ? data.terraform_remote_state.main[0].outputs.main_vpc_info.vpc_cidr_block : null
  #vpc_peering_connection_id = length(aws_vpc_peering_connection.to_main) > 0 ? aws_vpc_peering_connection.to_main[0].id : null

  depends_on = [null_resource.validate_outputs_or_fail]
}
