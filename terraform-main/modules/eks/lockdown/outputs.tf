# terraform-main/modules/eks/lockdown/outputs.tf

output "lockdown_triggered" {
  description = "Confirmation that EKS lockdown workflow was triggered"
  value       = "EKS lockdown workflow triggered for SG ${var.cluster_security_group_id}"
}

output "workflow_details" {
  description = "Details about the triggered workflow"
  value = {
    repo                      = "${var.github_org}/${var.github_repo}"
    security_group_id         = var.cluster_security_group_id
    environment              = var.environment
    workflow                 = "lockdown-eks.yml"
  }
}
