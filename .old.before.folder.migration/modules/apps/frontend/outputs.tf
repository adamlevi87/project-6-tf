# modules/apps/frontend/outputs.tf

output "iam_role_arn" {
  value = aws_iam_role.this.arn
}

# output "security_group_id" {
#   value = aws_security_group.alb_frontend.id
# }

# output "service_account_name" {
#   value = kubernetes_service_account.this.metadata[0].name
# }
