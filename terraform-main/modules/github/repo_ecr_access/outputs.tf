# terraform-main/modules/repo_ecr_access/outputs.tf

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "ARN of the IAM Role assumed by GitHub Actions"
}
