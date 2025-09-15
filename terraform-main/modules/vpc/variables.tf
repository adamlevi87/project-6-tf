# terraform-main/modules/vpc/variables.tf

variable "project_tag" {
  description = "Project tag for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
}

variable "primary_public_subnet_cidrs" {
  description = "Primary public subnet CIDRs that should always exist (houses primary NAT gateway)"
  type        = map(string)
}

variable "nat_mode" {
  description = "NAT gateway mode: 'single' (primary NAT only), 'real' (NAT per AZ), or 'endpoints' (no NATs)"
  type        = string
  validation {
    condition     = contains(["single", "real", "endpoints"], var.nat_mode)
    error_message = "NAT mode must be one of: single, real, endpoints"
  }
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs"
  type        = map(string)
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "additional_public_subnet_cidrs" {
  description = "Additional public subnet CIDRs (optional in single mode, required in real mode)"
  type        = map(string)
  default     = {}
}
