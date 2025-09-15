# terraform-requirements/main.tf

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# the ARN of this resource goes into the repo's secret PROVIDER_GITHUB_ARN
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# the ARN of this resources goes into the repo's secret AWS_ROLE_TO_ASSUME
resource "aws_iam_role" "github_actions" {
  name = "${var.project_tag}-${var.environment}-${var.aws_iam_role_github_actions_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${aws_iam_openid_connect_provider.github.url}:aud" = "sts.amazonaws.com"
          },
          StringLike = {
            "${aws_iam_openid_connect_provider.github.url}:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      },
      {
        Effect = "Allow",
        Principal = {
          AWS = [for user in var.kms_allowed_users : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${user}"]
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_admin_policy" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_s3_bucket" "tf_state" {
  bucket = var.aws_s3_bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project = var.project_tag
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "tf_state_versioning" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state_sse" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tf_state_key.arn
    }
    bucket_key_enabled = true  # Cost optimization
  }
}

resource "aws_dynamodb_table" "tf_lock" {
  name         = var.aws_dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Project = var.project_tag
    Environment = var.environment
  }
}

# KMS key with minimal policy (just root access)
resource "aws_kms_key" "tf_state_key" {
  description             = "KMS key for ${var.project_tag} Terraform state encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM policies"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_tag}-${var.environment}-tf-state-kms-key"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "terraform-state-encryption"
  }
}

# Separate IAM policy for Terraform role KMS access
resource "aws_iam_policy" "github_actions_kms_access" {
  name        = "${var.project_tag}-${var.environment}-github-actions-kms-access"
  description = "IAM policy for GitHub Actions to access Terraform state KMS key"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.tf_state_key.arn
      }
    ]
  })

  tags = {
    Name        = "${var.project_tag}-${var.environment}-github-actions-kms-policy"
    Project     = var.project_tag
    Environment = var.environment
  }
}

# Attach the KMS policy to the GitHub Actions role
resource "aws_iam_role_policy_attachment" "github_actions_kms_access" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_kms_access.arn
}

# KMS Alias for easier identification
resource "aws_kms_alias" "tf_state_key_alias" {
  name          = "alias/${var.project_tag}-${var.environment}-tf-state-encryption"
  target_key_id = aws_kms_key.tf_state_key.key_id
}
