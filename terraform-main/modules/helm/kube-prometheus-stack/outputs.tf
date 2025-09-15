# terraform-main/modules/helm/kube-prometheus-stack/outputs.tf

output "prometheus_service_name" {
  description = "Prometheus service name"
  value       = "${var.release_name}-prometheus"
}

output "grafana_service_name" {
  description = "Grafana service name"
  value       = "${var.release_name}-grafana"
}

output "alertmanager_service_name" {
  description = "AlertManager service name"
  value       = "${var.release_name}-alertmanager"
}

output "namespace" {
  description = "Monitoring namespace"
  value       = var.namespace
}

output "grafana_domain" {
  description = "Grafana domain URL"
  value       = "https://${var.grafana_domain}"
}

output "grafana_admin_credentials" {
  description = "Grafana admin login info"
  value = {
    username = "admin"
    password = var.grafana_admin_password
  }
  sensitive = true
}
