# modules/monitoring/service-monitors/outputs.tf

output "aws_lb_controller_servicemonitor_name" {
  description = "Name of the AWS Load Balancer Controller ServiceMonitor"
  value       = kubernetes_manifest.aws_load_balancer_controller_servicemonitor.manifest.metadata.name
}

output "argocd_server_servicemonitor_name" {
  description = "Name of the ArgoCD Server ServiceMonitor"
  value       = kubernetes_manifest.argocd_server_servicemonitor.manifest.metadata.name
}

output "argocd_application_controller_servicemonitor_name" {
  description = "Name of the ArgoCD Application Controller ServiceMonitor"
  value       = kubernetes_manifest.argocd_application_controller_servicemonitor.manifest.metadata.name
}

output "argocd_repo_server_servicemonitor_name" {
  description = "Name of the ArgoCD Repo Server ServiceMonitor"  
  value       = kubernetes_manifest.argocd_repo_server_servicemonitor.manifest.metadata.name
}

output "servicemonitor_names" {
  description = "Map of all created ServiceMonitor names"
  value = {
    aws_load_balancer_controller = kubernetes_manifest.aws_load_balancer_controller_servicemonitor.manifest.metadata.name
    argocd_server               = kubernetes_manifest.argocd_server_servicemonitor.manifest.metadata.name
    argocd_application_controller = kubernetes_manifest.argocd_application_controller_servicemonitor.manifest.metadata.name
    argocd_repo_server          = kubernetes_manifest.argocd_repo_server_servicemonitor.manifest.metadata.name
    argocd_dex_server           = var.enable_dex_metrics ? kubernetes_manifest.argocd_dex_server_servicemonitor[0].manifest.metadata.name : null
  }
}
