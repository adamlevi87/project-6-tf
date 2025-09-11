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

# # output "repository_url" {
# #   value       = aws_ecr_repository.this.repository_url
# #   description = "The URL of the ECR repository"
# # }

# # output "repository_name" {
# #   value       = aws_ecr_repository.this.name
# #   description = "The URL of the ECR repository"
# # }

# output "ecr_repository_names" {
#   description = "Map of app name to ECR repository names"
#   value = {
#     for app, repo in aws_ecr_repository.this :
#     app => repo.name
#   }
# }
