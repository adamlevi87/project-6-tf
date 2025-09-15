# terraform-main/modules/monitoring/service-monitors/outputs.tf

output "aws_lb_controller_podmonitor_name" {
  description = "Name of the AWS Load Balancer Controller PodMonitor"
  value       = "aws-load-balancer-controller"
}

output "argocd_server_servicemonitor_name" {
  description = "Name of the ArgoCD Server ServiceMonitor"
  value       = "argocd-server-metrics"
}

output "argocd_application_controller_servicemonitor_name" {
  description = "Name of the ArgoCD Application Controller ServiceMonitor"
  value       = "argocd-application-controller-metrics"
}

output "argocd_repo_server_servicemonitor_name" {
  description = "Name of the ArgoCD Repo Server ServiceMonitor"  
  value       = "argocd-repo-server-metrics"
}

output "servicemonitor_names" {
  description = "Map of all created ServiceMonitor names"
  value = {
    aws_load_balancer_controller = "aws-load-balancer-controller"
    argocd_server               = "argocd-server-metrics"
    argocd_application_controller = "argocd-application-controller-metrics"
    argocd_repo_server          = "argocd-repo-server-metrics"
    argocd_dex_server           = var.enable_dex_metrics ? "argocd-dex-server-metrics" : null
  }
}
