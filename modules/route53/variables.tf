# modules/route53/variables.tf

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

# variable "subdomain_name" {
#   type        = string
#   description = "Subdomain to use for the ALB (e.g. project-5)"
# }

# variable "cloudfront_domain_name" {
#   type        = string
#   description = "CloudFront distribution domain name"
#   default     = ""
# }

# variable "json_view_base_domain_name" {
#   description = "JSON viewer base domain name"
#   type        = string
# }

# variable "alb_dns_name" {
#   type        = string
#   description = "DNS name of the Application Load Balancer"
# }

# variable "alb_zone_id" {
#   type        = string
#   description = "Zone ID of the Application Load Balancer"
# }