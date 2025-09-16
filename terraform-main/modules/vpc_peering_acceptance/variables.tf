# terraform-main/modules/vpc_peering_acceptance/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "Main VPC ID (accepter VPC)"
  type        = string
}

# variable "runner_vpc_cidr" {
#   description = "CIDR block of the runner VPC"
#   type        = string
#   default     = "10.1.0.0/16"
# }

variable "private_route_table_ids" {
  description = "List of private route table IDs from main VPC"
  type        = list(string)
}
