# modules/kms/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

# KMS Key for S3 bucket encryption
resource "aws_kms_key" "s3_key" {
  description             = "KMS key for ${var.project_tag} ${var.environment} S3 bucket encryption"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM policies"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_tag}-${var.environment}-s3-kms-key"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "s3-encryption"
  }
}

# KMS Alias for easier identification
resource "aws_kms_alias" "s3_key_alias" {
  name          = "alias/${var.project_tag}-${var.environment}-s3-encryption"
  target_key_id = aws_kms_key.s3_key.key_id
}

# IAM role for KMS key management
resource "aws_iam_role" "kms_key_role" {
  name = "${var.project_tag}-${var.environment}-kms-key-role"

  # Allowing KMS to work with IAM policies
  # The extra -  per user/Role permissions are handled separately
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-${var.environment}-kms-key-role"
    Purpose     = "kms-key-management"
  }
}

# IAM policy for KMS key administration
resource "aws_iam_policy" "kms_key_admin_policy" {
  name        = "${var.project_tag}-${var.environment}-kms-key-admin"
  description = "IAM policy for KMS key administration"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ]
        Resource = aws_kms_key.s3_key.arn
      }
    ]
  })

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-${var.environment}-kms-key-admin-policy"
  }
}

# Attach admin policy to role
resource "aws_iam_role_policy_attachment" "kms_admin_attachment" {
  role       = aws_iam_role.kms_key_role.name
  policy_arn = aws_iam_policy.kms_key_admin_policy.arn
}
