# modules/kms/outputs.tf

output "kms_key_arn" {
  description = "The Amazon Resource Name (ARN) of the key"
  value       = aws_kms_key.s3_key.arn
}

# output "kms_key_id" {
#   description = "The globally unique identifier for the key"
#   value       = aws_kms_key.s3_key.key_id
# }

# output "kms_alias_arn" {
#   description = "The Amazon Resource Name (ARN) of the key alias"
#   value       = aws_kms_alias.s3_key_alias.arn
# }

# output "kms_alias_name" {
#   description = "The display name of the alias"
#   value       = aws_kms_alias.s3_key_alias.name
# }

# output "kms_role_arn" {
#   description = "The Amazon Resource Name (ARN) of the KMS role"
#   value       = aws_iam_role.kms_key_role.arn
# }

# output "kms_admin_policy_arn" {
#   description = "The Amazon Resource Name (ARN) of the KMS admin policy"
#   value       = aws_iam_policy.kms_key_admin_policy.arn
# }
