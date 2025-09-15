# terraform-main/modules/helm/metrics-server/main.tf

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0.2"
    }
  }
}

resource "helm_release" "this" {
  name       = var.release_name
  
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.chart_version
  
  namespace        = var.namespace
  create_namespace = false

  values = [
    yamlencode({
      serviceAccount = {
        create = false
        name   = var.service_account_name
      }
      
      args = [
        "--cert-dir=/tmp",
        "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
        "--kubelet-use-node-status-port", 
        "--kubelet-insecure-tls"
      ]
      
      service = {
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type" = "none"
        }
      }
      
      metrics = {
        enabled = false
      }
      
      serviceMonitor = {
        enabled = false
      }
      
      resources = {
        requests = {
          cpu    = var.cpu_requests
          memory = var.memory_requests
        }
        limits = {
          cpu    = var.cpu_limits
          memory = var.memory_limits
        }
      }
      

    })
  ]
  
  depends_on = [
    kubernetes_service_account.this
  ]
}

resource "kubernetes_service_account" "this" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace
    
    labels = {
      "app.kubernetes.io/name"     = "metrics-server"
      "app.kubernetes.io/instance" = var.release_name
      "app.kubernetes.io/component" = "metrics-server"
    }
  }
}
