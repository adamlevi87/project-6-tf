# .requirements/outputs.tf

# bypassing sensitive - only for testing
output "aws_iam_openid_connect_provider_github_arn" {
  description = "ARN of the GitHub OIDC provider (for PROVIDER_GITHUB_ARN secret)"
  value       = aws_iam_openid_connect_provider.github.arn
  #sensitive   = true
}

output "AWS_ROLE_TO_ASSUME" {
  description = "ARN of the GitHub Actions IAM role (for AWS_ROLE_TO_ASSUME secret)"
  value       = aws_iam_role.github_actions.arn
  #sensitive   = true
}