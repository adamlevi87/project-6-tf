# modules/helm/metrics-server/main.tf

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

  set = [
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = var.service_account_name
    },
    {
      name  = "args[0]"
      value = "--cert-dir=/tmp"
    },
    {
      name  = "args[1]"
      value = "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname"
    },
    {
      name  = "args[2]"
      value = "--kubelet-use-node-status-port"
    },
    {
      name  = "args[3]"
      value = "--kubelet-insecure-tls"
    },
    {
      name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
      value = "none"
    },
    {
      name  = "metrics.enabled"
      value = "false"
    },
    {
      name  = "serviceMonitor.enabled"
      value = "false"
    },
    {
      name  = "resources.requests.cpu"
      value = var.cpu_requests
    },
    {
      name  = "resources.requests.memory"
      value = var.memory_requests
    },
    {
      name  = "resources.limits.cpu"
      value = var.cpu_limits
    },
    {
      name  = "resources.limits.memory"
      value = var.memory_limits
    },
    {
      name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key"
      value = "kubernetes.io/os"
    },
    {
      name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator"
      value = "In"
    },
    {
      name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values[0]"
      value = "linux"
    }
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
