# modules/acm/outputs.tf

output "this_certificate_arn" {
  description = "ARN of the validated ACM certificate"
  value       = aws_acm_certificate.this.arn
}

# output "acm_dns_records_to_add" {
#   description = "Manual DNS records for ACM validation if Route53 fails"
#   value = [
#     for dvo in aws_acm_certificate.this.domain_validation_options : {
#       name   = dvo.resource_record_name
#       type   = dvo.resource_record_type
#       value  = dvo.resource_record_value
#     }
#   ]
# }

# output "certificate_validation_status" {
#   value = aws_acm_certificate_validation.this.certificate_arn
# }
