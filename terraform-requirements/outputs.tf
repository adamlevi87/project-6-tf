# terraform-requirements/outputs.tf

# bypassing sensitive - only for testing
output "aws_iam_openid_connect_provider_github_arn" {
  description = "ARN of the GitHub OIDC provider (for PROVIDER_GITHUB_ARN secret)"
  value       = aws_iam_openid_connect_provider.github.arn
  #sensitive   = true
}

output "github_oidc_role_arn" {
  description = "ARN of the GitHub Actions IAM role (for AWS_ROLE_TO_ASSUME secret)"
  value       = aws_iam_role.github_actions.arn
  #sensitive   = true
}

output "terraform_backend_bucket" {
  description = "S3 bucket name for Terraform backend"
  value       = aws_s3_bucket.tf_state.bucket
}

output "terraform_backend_dynamodb_table" {
  description = "DynamoDB table name for Terraform state locking"
  value       = aws_dynamodb_table.tf_lock.name
}

output "terraform_backend_kms_key_alias" {
  description = "KMS key alias for Terraform state encryption"
  value       = aws_kms_alias.tf_state_key_alias.name
}
