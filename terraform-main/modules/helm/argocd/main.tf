# terraform-main/modules/helm/argocd/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
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

locals {  
  project_object = merge(
    yamldecode(var.argocd_project_yaml),
    {
      metadata = merge(
        yamldecode(var.argocd_project_yaml).metadata,
        {
          annotations = merge(
            try(yamldecode(var.argocd_project_yaml).metadata.annotations, {}),
            {
              "helm.sh/hook"                = "post-install,post-upgrade"
              "helm.sh/hook-weight"         = "1"
              "helm.sh/hook-delete-policy"  = "before-hook-creation"
            }
          )
        }
      )
    }
  )
  
  app_of_apps_object = merge(
    yamldecode(var.argocd_app_of_apps_yaml),
    {
      metadata = merge(
        yamldecode(var.argocd_app_of_apps_yaml).metadata,
        {
          annotations = merge(
            try(yamldecode(var.argocd_app_of_apps_yaml).metadata.annotations, {}),
            {
              "helm.sh/hook"                 = "post-install,post-upgrade"
              "helm.sh/hook-weight"          = "5"
              "helm.sh/hook-delete-policy"   = "before-hook-creation"
              "argocd.argoproj.io/sync-wave" = "-10"
            }
          )
        }
      )
    }
  )

  argocd_additionalObjects = [
    local.project_object,
    local.app_of_apps_object
  ]
}

resource "random_password" "argocd_server_secretkey" {
  length  = 48
  special = false
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "this" {
  name       = var.release_name
  
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version
  namespace  = var.namespace

  create_namespace = false
  wait            = true
  timeout         = 600

  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      # Core configuration
      service_account_name        = var.service_account_name
      environment                 = var.environment
      domain_name                 = var.domain_name
      release_name                = var.release_name

      # ALB configuration
      alb_group_name              = var.alb_group_name
      security_group_ids          = var.alb_security_groups
      acm_cert_arn                = var.acm_cert_arn
      allowed_cidrs               = jsonencode(var.argocd_allowed_cidr_blocks)
      ingress_controller_class    = var.ingress_controller_class

      # GitHub SSO
      github_org                  = var.github_org
      github_admin_team           = var.github_admin_team
      github_readonly_team        = var.github_readonly_team
      argocd_github_sso_secret_name = var.argocd_github_sso_secret_name
      dollar                      = "$"
      server_secretkey            = random_password.argocd_server_secretkey.result

      # ================================
      # Resource Configuration
      # ================================
      # Server
      server_memory_requests = var.server_memory_requests
      server_cpu_requests    = var.server_cpu_requests
      server_memory_limits   = var.server_memory_limits
      server_cpu_limits      = var.server_cpu_limits
      
      # Controller
      controller_memory_requests = var.controller_memory_requests
      controller_cpu_requests    = var.controller_cpu_requests
      controller_memory_limits   = var.controller_memory_limits
      controller_cpu_limits      = var.controller_cpu_limits
      
      # Repo Server
      repo_server_memory_requests = var.repo_server_memory_requests
      repo_server_cpu_requests    = var.repo_server_cpu_requests
      repo_server_memory_limits   = var.repo_server_memory_limits
      repo_server_cpu_limits      = var.repo_server_cpu_limits
      
      # Dex Server
      dex_memory_requests = var.dex_memory_requests
      dex_cpu_requests    = var.dex_cpu_requests
      dex_memory_limits   = var.dex_memory_limits
      dex_cpu_limits      = var.dex_cpu_limits
      
      # ================================
      # Metrics Configuration
      # ================================
      # Server metrics
      server_metrics_enabled       = var.server_metrics_enabled
      server_metrics_port          = var.server_metrics_port
      server_metrics_port_name     = var.server_metrics_port_name
      server_metrics_scrape_enabled = var.server_metrics_scrape_enabled
      server_metrics_path          = var.server_metrics_path
      server_metrics_labels        = var.server_metrics_labels
      
      # Controller metrics
      controller_metrics_enabled       = var.controller_metrics_enabled
      controller_metrics_port          = var.controller_metrics_port
      controller_metrics_port_name     = var.controller_metrics_port_name
      controller_metrics_scrape_enabled = var.controller_metrics_scrape_enabled
      controller_metrics_path          = var.controller_metrics_path
      controller_metrics_labels        = var.controller_metrics_labels
      
      # Repo Server metrics
      repo_server_metrics_enabled       = var.repo_server_metrics_enabled
      repo_server_metrics_port          = var.repo_server_metrics_port
      repo_server_metrics_port_name     = var.repo_server_metrics_port_name
      repo_server_metrics_scrape_enabled = var.repo_server_metrics_scrape_enabled
      repo_server_metrics_path          = var.repo_server_metrics_path
      repo_server_metrics_labels        = var.repo_server_metrics_labels
      
      # Dex Server metrics
      dex_metrics_enabled       = var.dex_metrics_enabled
      dex_metrics_port          = var.dex_metrics_port
      dex_metrics_port_name     = var.dex_metrics_port_name
      dex_metrics_scrape_enabled = var.dex_metrics_scrape_enabled
      dex_metrics_path          = var.dex_metrics_path
      dex_metrics_labels        = var.dex_metrics_labels
    }),
    yamlencode({
      extraObjects = local.argocd_additionalObjects
    })
  ]
  
  depends_on = [
      kubernetes_namespace.this,
      kubernetes_service_account.this
  ]
}

# Kubernetes service account
resource "kubernetes_service_account" "this" {
  metadata {
    name      = "${var.service_account_name}"
    namespace = "${var.namespace}"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
    }
  }
}

resource "aws_iam_role" "this" {
  name = "${var.project_tag}-${var.environment}-${var.service_account_name}-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity",
        Effect = "Allow",
        Principal = {
          Federated = var.oidc_provider_arn
        },
        Condition = {
        StringEquals = {
          "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}",
          "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
      }
    ]
  })
}

resource "aws_iam_role_policy" "this" {
  name = "${var.service_account_name}-policy"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "${var.secret_arn}"
      }
    ]
  })
}
