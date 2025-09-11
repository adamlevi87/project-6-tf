# modules/argocd/main.tf

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
  #joined_security_group_ids = "${aws_security_group.alb_argocd.id},${var.frontend_security_group_id}"
  
  argocd_additionalObjects = [
    yamldecode(var.argocd_project_yaml),
    yamldecode(var.argocd_app_of_apps_yaml)
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
      security_group_id           = var.alb_security_groups
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

# # Security Group for ArgoCD
# # SG to be applied onto the ALB (happens when argoCD creates the Shared ALB)
# resource "aws_security_group" "alb_argocd" {
#   name        = "${var.project_tag}-${var.environment}-argocd-sg"
#   description = "Security group for argocd"
#   vpc_id      = var.vpc_id

#   # Allow ArgoCD access from the outside
#   # 80 will be redirected to 443 (controlled via argocd values file values.yaml.tpl ingress section)
#   dynamic "ingress" {
#     for_each = [80, 443]
#     content {
#       from_port   = ingress.value
#       to_port     = ingress.value
#       protocol    = "tcp"
#       cidr_blocks = var.argocd_allowed_cidr_blocks
#       description = "ArgoCD access on port ${ingress.value}"
#     }
#   }

#   # Outbound rules (usually not needed but good practice)
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#     description = "All outbound traffic"
#   }

#   tags = {
#     Project     = var.project_tag
#     Environment = var.environment
#     Name        = "${var.project_tag}-${var.environment}-argocd-sg"
#     Purpose     = "argocd-security"
#   }
# }

# resource "aws_security_group_rule" "allow_alb_to_argocd_pods" {
#   for_each = var.node_group_security_groups

#   type                     = "ingress"
#   from_port                = 8080
#   to_port                  = 8080
#   protocol                 = "tcp"
#   security_group_id        = each.value
#   source_security_group_id = aws_security_group.alb_argocd.id
#   description              = "Allow ALB to access ArgoCD pods on port 8080 (${each.key} nodes)"
# }
