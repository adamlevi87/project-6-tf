# modules/apps/frontend/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38.0"
    }
  }
}

resource "aws_iam_role" "this" {
  name = "${var.project_tag}-${var.environment}-${var.service_account_name}-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity",
        Effect = "Allow",
        Principal = {
          Federated = var.oidc_provider_arn
        },
        Condition = {
        StringEquals = {
          "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}",
          "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
      }
    ]
  })
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace

    labels = {
      name = var.namespace
    }
  }
}

resource "kubernetes_service_account" "this" {
  metadata {
    name      = var.service_account_name
    namespace = kubernetes_namespace.this.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
    }
  }
}

# IAM policy for frontend s3 access
resource "aws_iam_policy" "frontend_s3_access" {
  name        = "${var.project_tag}-${var.environment}-frontend-s3-access"
  description = "IAM policy for frontend to access S3 app data bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${var.s3_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "${var.s3_bucket_arn}"
      }
    ]
  })

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-${var.environment}-frontend-s3-policy"
  }
}

# IAM policy for frontend KMS access
resource "aws_iam_policy" "frontend_kms_access" {
  name        = "${var.project_tag}-${var.environment}-frontend-kms-access"
  description = "IAM policy for frontend to access KMS key for S3 encryption"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:DescribeKey"
        ]
        Resource = "${var.kms_key_arn}"
      }
    ]
  })

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-${var.environment}-frontend-kms-policy"
  }
}

# Attach S3 access policy
resource "aws_iam_role_policy_attachment" "frontend_s3_access" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.frontend_s3_access.arn
}

# Attach KMS access policy
resource "aws_iam_role_policy_attachment" "frontend_kms_access" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.frontend_kms_access.arn
}
