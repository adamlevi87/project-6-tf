# modules/argocd/outputs.tf

output "service_account_role_arn" {
  description = "The ARN of the IAM role of the service account of argocd"
  value       = aws_iam_role.this.arn
}

# output "joined_security_group_ids" {
#   description = "a string of all the security group IDs separated by commas"
#   value       = local.joined_security_group_ids
# }
