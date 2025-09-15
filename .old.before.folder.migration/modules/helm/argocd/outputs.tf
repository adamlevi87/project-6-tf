# modules/helm/argocd/outputs.tf

output "service_account_role_arn" {
  description = "The ARN of the IAM role of the service account of argocd"
  value       = aws_iam_role.this.arn
}
