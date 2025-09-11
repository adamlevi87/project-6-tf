# .requirements/main.tf

provider "aws" {
  region = var.aws_region
}

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
          StringLike = {
            "${aws_iam_openid_connect_provider.github.url}:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_admin_policy" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# resource "aws_s3_bucket" "tf_state" {
#   bucket = var.aws_s3_bucket_name

#   lifecycle {
#     prevent_destroy = true
#   }

#   tags = {
#     Project = var.project_tag
#     Environment = var.environment
#   }
# }

# resource "aws_s3_bucket_versioning" "tf_state_versioning" {
#   bucket = aws_s3_bucket.tf_state.id

#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state_sse" {
#   bucket = aws_s3_bucket.tf_state.id

#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }

# resource "aws_dynamodb_table" "tf_lock" {
#   name         = var.aws_dynamodb_table_name
#   billing_mode = "PAY_PER_REQUEST"
#   hash_key     = "LockID"

#   attribute {
#     name = "LockID"
#     type = "S"
#   }

#   tags = {
#     Project = var.project_tag
#     Environment = var.environment
#   }
# }
