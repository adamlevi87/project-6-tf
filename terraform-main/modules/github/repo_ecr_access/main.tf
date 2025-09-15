# terraform-main/modules/repo_ecr_access/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project_tag}-${var.environment}-${var.github_repo}-github-actions-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity",
        Effect = "Allow",
        Principal = {
          Federated = var.aws_iam_openid_connect_provider_github_arn
        },
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-${var.environment}-github-actions-role"
    Purpose     = "github-actions-oidc"
  }
}

# Create custom ECR policy instead of AdministratorAccess
resource "aws_iam_policy" "github_actions_ecr_policy" {
  name        = "${var.project_tag}-${var.environment}-github-actions-ecr-policy"
  description = "IAM policy for GitHub Actions to access ECR repositories"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Global ECR permissions (required for authentication)
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        # Repository-specific ECR permissions
        Effect = "Allow"
        Action = [
          # Read permissions (for getting image details/digests)
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          
          # Write permissions (for pushing images)
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = var.ecr_repository_arns
      }
    ]
  })

  tags = {
    Name        = "${var.project_tag}-${var.environment}-github-actions-ecr-policy"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "github-actions-ecr-access"
  }
}

# Attach the custom ECR policy instead of AdministratorAccess
resource "aws_iam_role_policy_attachment" "attach_ecr_policy" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_ecr_policy.arn
}
