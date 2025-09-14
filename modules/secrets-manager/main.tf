# modules/secrets-manager/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

resource "aws_secretsmanager_secret" "app_secrets" {
  for_each = toset(var.secret_keys)

  name        = "${var.project_tag}-${var.environment}-${each.key}"
  description = var.app_secrets_config[each.key].description
  recovery_window_in_days = 0

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-${var.environment}-${each.key}"
    Purpose     = "application-secrets"
    SecretType  = each.key
  }
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  for_each = toset(var.secret_keys)

  secret_id     = aws_secretsmanager_secret.app_secrets[each.key].id
  secret_string = var.app_secrets_config[each.key].secret_value
}


# Create secrets in AWS Secrets Manager
resource "aws_secretsmanager_secret" "secrets" {
  for_each = var.secrets_config_with_passwords

  name        = "${var.project_tag}-${var.environment}-${each.key}"
  description = each.value.description
  recovery_window_in_days = 0  # Force immediate deletion for dev environments

  tags = {
    Name        = "${var.project_tag}-${var.environment}-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "application-secrets"
    SecretType  = each.key
  }
}

# Store secret values
resource "aws_secretsmanager_secret_version" "secrets" {
  for_each = var.secrets_config_with_passwords

  secret_id = aws_secretsmanager_secret.secrets[each.key].id
  
  secret_string = each.value.secret_value
}
