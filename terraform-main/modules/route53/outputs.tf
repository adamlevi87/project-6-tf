# terraform-main/modules/route53/outputs.tf

output "zone_id" {
  description = "Route53 Hosted Zone ID"
  value = aws_route53_zone.this.zone_id
}
