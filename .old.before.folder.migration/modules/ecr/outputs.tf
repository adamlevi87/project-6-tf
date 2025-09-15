# modules/ecr/outputs.tf

output "ecr_repository_arns" {
  description = "Map of app name to ECR repository ARNs"
  value = {
    for app, repo in aws_ecr_repository.this :
    app => repo.arn
  }
}

output "ecr_repository_urls" {
  description = "Map of app name to ECR repository URLs"
  value = {
    for app, repo in aws_ecr_repository.this :
    app => repo.repository_url
  }
}
