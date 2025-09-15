# modules/monitoring/grafana-dashboards/main.tf

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38.0"
    }
  }
}

# ArgoCD Dashboard ConfigMap
resource "kubernetes_config_map" "argocd_dashboard-1" {
  metadata {
    name      = "argocd-dashboard-1"
    namespace = var.monitoring_namespace
    labels = {
      "grafana_dashboard" = "1"
    }
    annotations = {
      "grafana-folder" = "ArgoCD"
    }
  }
  
  data = {
    "argocd-dashboard-1.json" = templatefile("${path.module}/dashboards/argocd-1.json.tpl", {
      datasource = var.prometheus_datasource_name
    })
  }
}

# ArgoCD Dashboard ConfigMap
resource "kubernetes_config_map" "argocd_dashboard-2" {
  metadata {
    name      = "argocd-dashboard-2"
    namespace = var.monitoring_namespace
    labels = {
      "grafana_dashboard" = "1"
    }
    annotations = {
      "grafana-folder" = "ArgoCD"
    }
  }
  
  data = {
    "argocd-dashboard-2.json" = templatefile("${path.module}/dashboards/argocd-2.json.tpl", {
      datasource = var.prometheus_datasource_name
    })
  }
}

# AWS Load Balancer Controller Dashboard ConfigMap
resource "kubernetes_config_map" "aws_lbc_dashboard" {
  count = var.enable_aws_lbc_dashboard ? 1 : 0
  
  metadata {
    name      = "aws-lbc-dashboard"
    namespace = var.monitoring_namespace
    labels = {
      "grafana_dashboard" = "1"
    }
    annotations = {
      "grafana-folder" = "AWS"
    }
  }
  
  data = {
    "aws-lbc-dashboard.json" = templatefile("${path.module}/dashboards/aws-lbc.json.tpl", {
      DS_PROMETHEUS = var.prometheus_datasource_name
    })
  }
}
