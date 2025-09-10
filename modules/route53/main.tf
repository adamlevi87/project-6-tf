# modules/route53/main.tf

terraform {
  # latest versions of each provider for 09/2025
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

resource "aws_route53_zone" "this" {
  name = var.domain_name
  comment = "Hosted zone for ${var.project_tag}"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
  }
}

# resource "aws_route53_record" "cloudfront_json_viewer" {
#   zone_id = aws_route53_zone.this.zone_id
#   name    = "${var.json_view_base_domain_name}.${var.subdomain_name}"
#   type    = "CNAME"
#   ttl     = 300

#   records = [var.cloudfront_domain_name]
# }

# # A record pointing to the ALB
# resource "aws_route53_record" "app_dns" {
#   zone_id = aws_route53_zone.this.zone_id
#   name    = var.subdomain_name
#   type    = "A"

#   alias {
#     name                   = var.alb_dns_name
#     zone_id                = var.alb_zone_id
#     evaluate_target_health = true
#   }
# }