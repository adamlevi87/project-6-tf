# modules/monitoring/grafana-dashboards/outputs.tf

output "argocd_dashboard_configmap_name" {
  description = "Name of the ArgoCD dashboard ConfigMap"
  value       = kubernetes_config_map.argocd_dashboard-1.metadata[0].name
}

output "dashboard_configmaps" {
  description = "List of all created dashboard ConfigMaps"
  value = compact([
    kubernetes_config_map.argocd_dashboard-1.metadata[0].name,
    kubernetes_config_map.argocd_dashboard-2.metadata[0].name,
    try(kubernetes_config_map.aws_lbc_dashboard[0].metadata[0].name, null)
  ])
}
