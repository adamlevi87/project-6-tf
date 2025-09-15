# modules/ebs-csi-driver/outputs.tf

output "service_account_name" {
  description = "EBS CSI driver service account name"
  value       = kubernetes_service_account.ebs_csi_driver.metadata[0].name
}

output "iam_role_arn" {
  description = "EBS CSI driver IAM role ARN"
  value       = aws_iam_role.ebs_csi_driver_role.arn
}
