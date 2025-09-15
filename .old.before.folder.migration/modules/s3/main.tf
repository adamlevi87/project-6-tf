# modules/s3/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

resource "aws_s3_bucket" "app_data" {
  bucket = "${var.project_tag}-${var.environment}-app-data-${random_string.bucket_suffix.result}"

  # Enable force destroy to allow deletion of non-empty bucket
  force_destroy = var.force_destroy

  tags = {
    Name        = "${var.project_tag}-${var.environment}-app-data"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "application-data"
  }
}

# Random suffix to ensure bucket name uniqueness
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Enable versioning
resource "aws_s3_bucket_versioning" "app_data_versioning" {
  bucket = aws_s3_bucket.app_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption with SSE-KMS and bucket key
resource "aws_s3_bucket_server_side_encryption_configuration" "app_data_encryption" {
  bucket = aws_s3_bucket.app_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true  # Enable S3 Bucket Key for cost optimization
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "app_data_pab" {
  bucket = aws_s3_bucket.app_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "app_data_lifecycle" {
  count  = var.enable_lifecycle_policy ? 1 : 0
  bucket = aws_s3_bucket.app_data.id

  rule {
    id     = "app_data_lifecycle"
    status = "Enabled"

    # Apply to all objects in the bucket
    filter {
      prefix = ""
    }
    # Move to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Move to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Delete after specified retention period
    dynamic "expiration" {
      for_each = var.data_retention_days > 0 ? [1] : []
      content {
        days = var.data_retention_days
      }
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Base restrictive policy - DENY ALL by default (only root can access initially)
resource "aws_s3_bucket_policy" "base_restrictive" {
  bucket     = aws_s3_bucket.app_data.id
  depends_on = [aws_s3_bucket_public_access_block.app_data_pab]
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowAdministrators"
        Effect    = "Allow"
        Principal = {
          AWS = var.allowed_principals
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.app_data.arn,
          "${aws_s3_bucket.app_data.arn}/*"
        ]
      },
      {
        Sid       = var.s3_policy_deny_rule_name
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.app_data.arn,
          "${aws_s3_bucket.app_data.arn}/*"
        ]
        Condition = {
          StringNotEquals = {
            "aws:PrincipalArn" = var.allowed_principals
          }
        }
      }
    ]
  })
}
