# modules/argocd/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = var.aws_provider_version
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = var.kubernetes_provider_version
    }
    helm = {
      source  = "hashicorp/helm"
      version = var.helm_provider_version
    }
  }
}

locals {
  joined_security_group_ids = "${aws_security_group.alb_argocd.id},${var.frontend_security_group_id}"
  
  argocd_additionalObjects = [
    # 1) setting up the Project
    {
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "AppProject"
      metadata = {
        name      = "${var.project_tag}"
        namespace = "${var.namespace}"
        annotations = {
          "helm.sh/hook"                = "post-install,post-upgrade"
          "helm.sh/hook-weight"         = "1"
          "helm.sh/hook-delete-policy"  = "before-hook-creation"
        }
      }
      spec = {
        description = "${var.project_tag} apps and infra"
        sourceRepos = [
          "https://github.com/${var.github_org}/${var.github_gitops_repo}.git",
          "https://github.com/${var.github_org}/${var.github_application_repo}.git"
        ]
        destinations = [
          {
            namespace = "*"
            server    = "https://kubernetes.default.svc"
          }
        ]
        namespaceResourceWhitelist = [
          {
            group = ""
            kind  = "Secret"
          },
          {
            group = ""
            kind  = "ServiceAccount"
          },
          {
            group = "networking.k8s.io"
            kind  = "Ingress"
          },
          {
            group = ""
            kind  = "Service"
          },
          {
            group = "apps"
            kind  = "Deployment"
          },
          {
            group = "argoproj.io"
            kind  = "Application"
          },
          {
            group = "autoscaling"
            kind  = "HorizontalPodAutoscaler"
          }
        ]
        clusterResourceWhitelist = []
        orphanedResources = {
          warn = true
        }
      } 
    },
    # 2) setting up App-of-Apps
    {
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "Application"
      metadata = {
        name      = "${var.project_tag}-app-of-apps-${var.environment}"
        namespace = "${var.namespace}"
        annotations = {
          "helm.sh/hook"                 = "post-install,post-upgrade"
          "helm.sh/hook-weight"          = "5"
          "helm.sh/hook-delete-policy"   = "before-hook-creation"
          "argocd.argoproj.io/sync-wave" = "-10"
        }
      }
      spec = {
        project = "${var.project_tag}"
        source = {
          repoURL        = "https://github.com/${var.github_org}/${var.github_gitops_repo}.git"
          path           = "environments/${var.environment}/${var.app_of_apps_path}"
          targetRevision = "${var.app_of_apps_target_revision}"
          directory = {
            recurse = true
          }
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "default"
        }
        revisionHistoryLimit = 3
        syncPolicy = {
          retry = {
            limit = 5
            backoff = {
              duration    = "5s"
              factor      = 2
              maxDuration = "3m"
            }
          }
          syncOptions = [
            "CreateNamespace=true",
            "PruneLast=true",
            "PrunePropagationPolicy=background",
            "ApplyOutOfSyncOnly=true"
          ]
        }
      }
    }
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

  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      service_account_name        = var.service_account_name
      environment                 = var.environment
      domain_name                 = var.domain_name
      ingress_controller_class    = var.ingress_controller_class
      alb_group_name              = var.alb_group_name
      release_name                = var.release_name
      allowed_cidrs               = jsonencode(var.argocd_allowed_cidr_blocks)
      security_group_id           = local.joined_security_group_ids
      acm_cert_arn                = var.acm_cert_arn
      server_secretkey            = random_password.argocd_server_secretkey.result
      github_org                  = var.github_org
      github_admin_team           = var.github_admin_team
      github_readonly_team        = var.github_readonly_team
      dollar                      = "$"
      argocd_github_sso_secret_name = var.argocd_github_sso_secret_name
    }),
    yamlencode({
      extraObjects = local.argocd_additionalObjects
    })
  ]
  
  depends_on = [
      kubernetes_namespace.this,
      kubernetes_service_account.this,
      aws_security_group.alb_argocd
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

# Security Group for ArgoCD
# SG to be applied onto the ALB (happens when argoCD creates the Shared ALB)
resource "aws_security_group" "alb_argocd" {
  name        = "${var.project_tag}-${var.environment}-argocd-sg"
  description = "Security group for argocd"
  vpc_id      = var.vpc_id

  # Allow ArgoCD access from the outside
  # 80 will be redirected to 443 (controlled via argocd values file values.yaml.tpl ingress section)
  dynamic "ingress" {
    for_each = [80, 443]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.argocd_allowed_cidr_blocks
      description = "ArgoCD access on port ${ingress.value}"
    }
  }

  # Outbound rules (usually not needed but good practice)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-${var.environment}-argocd-sg"
    Purpose     = "argocd-security"
  }
}

resource "aws_security_group_rule" "allow_alb_to_argocd_pods" {
  for_each = var.node_group_security_groups

  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = each.value
  source_security_group_id = aws_security_group.alb_argocd.id
  description              = "Allow ALB to access ArgoCD pods on port 8080 (${each.key} nodes)"
}


# resource "aws_iam_role_policy" "this" {
#   name = "${var.service_account_name}-policy"
#   role = aws_iam_role.this.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "secretsmanager:GetSecretValue"
#         ]
#         Resource = "${var.secret_arn}"
#       }
#     ]
#   })
# }
