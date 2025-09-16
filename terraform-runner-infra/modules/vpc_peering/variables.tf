# terraform-main/modules/vpc_peering/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "source_vpc_id" {
  description = "VPC ID of the source VPC (runner VPC)"
  type        = string
}

variable "initialize_run" {
  description = "Whether this is an initialization run (true = deploy basics only, false = deploy everything)"
  type        = bool
}

# variable "peer_vpc_id" {
#   description = "VPC ID of the peer VPC (main project VPC)"
#   type        = string
# }

# variable "peer_vpc_cidr" {
#   description = "CIDR block of the peer VPC (main project VPC)"
#   type        = string
# }

# variable "peer_region" {
#   description = "AWS region of the peer VPC"
#   type        = string
# }

variable "source_route_table_id" {
  description = "Route table ID of the source VPC private subnet"
  type        = string
}
