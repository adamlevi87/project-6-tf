# # terraform-main/modules/github/self_hosted_runner/outputs.tf

# output "runner_security_group_id" {
#   description = "Security group ID for GitHub runners"
#   value       = aws_security_group.github_runner.id
# }

output "runner_instance_role_arn" {
  description = "IAM role ARN for GitHub runner instances"
  value       = aws_iam_role.github_runner_instance.arn
}

# output "runner_launch_template_id" {
#   description = "Launch template ID for GitHub runners"
#   value       = aws_launch_template.github_runner.id
# }

# output "runner_autoscaling_group_name" {
#   description = "Auto Scaling Group name for GitHub runners"
#   value       = aws_autoscaling_group.github_runner.name
# }

# output "runner_autoscaling_group_arn" {
#   description = "Auto Scaling Group ARN for GitHub runners"
#   value       = aws_autoscaling_group.github_runner.arn
# }

# output "runner_labels" {
#   description = "Labels assigned to GitHub runners"
#   value       = var.runner_labels
# }
