# modules/secrets-manager/outputs.tf

output "app_secrets_names" {
  description = "Map of secret Names by values from *_aws_secret_key"
  value       = { for name, secret in aws_secretsmanager_secret.app_secrets : name => secret.name }
}

output "app_secrets_arns" {
  description = "Map of secret ARNs by values from *_aws_secret_key"
  value       = { for name, secret in aws_secretsmanager_secret.app_secrets : name => secret.arn }
}

# output "secret_arns" {
#   description = "Map of secret ARNs by secret name"
#   value       = { for name, secret in aws_secretsmanager_secret.secrets : name => secret.arn }
# }

# output "secret_names" {
#   description = "Map of secret names by secret key"
#   value       = { for name, secret in aws_secretsmanager_secret.secrets : name => secret.name }
# }

# output "secret_ids" {
#   description = "Map of secret IDs by secret name"
#   value       = { for name, secret in aws_secretsmanager_secret.secrets : name => secret.id }
# }