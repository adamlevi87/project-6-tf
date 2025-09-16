# terraform-main/modules/vpc_peering_acceptance/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "initialize_run" {
  description = "Whether this is an initialization run (true = deploy basics only, false = deploy everything)"
  type        = bool
}

variable "peering_connection_id" {
  description = "VPC peering connection ID from runner infrastructure (via remote state)"
  type        = string
}

variable "runner_vpc_cidr" {
  description = "CIDR block of the runner VPC (via remote state)"
  type        = string
}

variable "private_route_table_ids" {
  description = "List of private route table IDs from main VPC"
  type        = list(string)
}

# variable "aws_region" {
#   description = "AWS region"
#   type        = string
# }

# variable "vpc_id" {
#   description = "Main VPC ID (accepter VPC)"
#   type        = string
# }

