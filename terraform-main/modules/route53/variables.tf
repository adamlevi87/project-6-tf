# terraform-main/modules/route53/variables.tf

variable "project_tag" {
  type        = string
  description = "Tag to identify the project resources"
}

variable "environment" {
  type        = string
  description = "Deployment environment name (e.g. dev, prod)"
}

variable "domain_name" {
  type        = string
  description = "The root domain name to manage with Route53 (e.g. yourdomain.com)"
}
