# terraform-main/modules/monitoring/service-monitors/main.tf

terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19.0"
    }
  }
}

# ServiceMonitor for AWS Load Balancer Controller
resource "kubectl_manifest" "aws_load_balancer_controller_podmonitor" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PodMonitor"
    metadata = {
      name      = "aws-load-balancer-controller"
      namespace = var.monitoring_namespace
      labels = {
        "app.kubernetes.io/name"      = "aws-load-balancer-controller"
        "app.kubernetes.io/component" = "controller"
        "prometheus.io/monitor"       = "true"
      }
    }
    spec = {
      jobLabel = "aws-load-balancer-controller"
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "aws-load-balancer-controller"
        }
      }
      namespaceSelector = {
        matchNames = [var.aws_lb_controller_namespace]
      }
      podMetricsEndpoints = [
        {
          port     = "metrics-server"
          interval = "30s"
          path     = "/metrics"
          scheme   = "http"
        }
      ]
    }
  })
}

# ServiceMonitor for ArgoCD Server
resource "kubectl_manifest" "argocd_server_servicemonitor" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "argocd-server-metrics"
      namespace = var.monitoring_namespace
      labels = {
        "app.kubernetes.io/name"      = "argocd-server"
        "app.kubernetes.io/component" = "server"
        "prometheus.io/monitor"       = "true"
      }
    }
    spec = {
      jobLabel = "argocd-server"
      selector = {
        matchLabels = {
          "app.kubernetes.io/component" = "server"
          "app.kubernetes.io/name"      = "argocd-server-metrics"
        }
      }
      namespaceSelector = {
        matchNames = [var.argocd_namespace]
      }
      endpoints = [
        {
          port     = "http-metrics"
          interval = "30s"
          path     = "/metrics"
          scheme   = "http"
        }
      ]
    }
  })
}

# ServiceMonitor for ArgoCD Application Controller
resource "kubectl_manifest" "argocd_application_controller_servicemonitor" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "argocd-application-controller-metrics"
      namespace = var.monitoring_namespace
      labels = {
        "app.kubernetes.io/name"      = "argocd-application-controller"
        "app.kubernetes.io/component" = "application-controller"
        "prometheus.io/monitor"       = "true"
      }
    }
    spec = {
      jobLabel = "argocd-application-controller"
      selector = {
        matchLabels = {
          "app.kubernetes.io/component" = "application-controller"
          "app.kubernetes.io/name"      = "argocd-application-controller-metrics"
        }
      }
      namespaceSelector = {
        matchNames = [var.argocd_namespace]
      }
      endpoints = [
        {
          port     = "http-metrics"
          interval = "30s"
          path     = "/metrics"
          scheme   = "http"
        }
      ]
    }
  })
}

# ServiceMonitor for ArgoCD Repo Server
resource "kubectl_manifest" "argocd_repo_server_servicemonitor" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "argocd-repo-server-metrics"
      namespace = var.monitoring_namespace
      labels = {
        "app.kubernetes.io/name"      = "argocd-repo-server"
        "app.kubernetes.io/component" = "repo-server"
        "prometheus.io/monitor"       = "true"
      }
    }
    spec = {
      jobLabel = "argocd-repo-server"
      selector = {
        matchLabels = {
          "app.kubernetes.io/component" = "repo-server"
          "app.kubernetes.io/name"      = "argocd-repo-server-metrics"
        }
      }
      namespaceSelector = {
        matchNames = [var.argocd_namespace]
      }
      endpoints = [
        {
          port     = "http-metrics"
          interval = "30s"
          path     = "/metrics"
          scheme   = "http"
        }
      ]
    }
  })
}

# Optional: ServiceMonitor for ArgoCD Dex Server (if enabled)
resource "kubectl_manifest" "argocd_dex_server_servicemonitor" {
  count = var.enable_dex_metrics ? 1 : 0
  
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "argocd-dex-server-metrics"
      namespace = var.monitoring_namespace
      labels = {
        "app.kubernetes.io/name"      = "argocd-dex-server"
        "app.kubernetes.io/component" = "dex-server"
        "prometheus.io/monitor"       = "true"
      }
    }
    spec = {
      jobLabel = "argocd-dex-server"
      selector = {
        matchLabels = {
          "app.kubernetes.io/component" = "dex-server"
          "app.kubernetes.io/name"      = "argocd-dex-server-metrics"
        }
      }
      namespaceSelector = {
        matchNames = [var.argocd_namespace]
      }
      endpoints = [
        {
          port     = "http-metrics"
          interval = "30s"
          path     = "/metrics"
          scheme   = "http"
        }
      ]
    }
  })
}
