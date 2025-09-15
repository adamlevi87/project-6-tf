# modules/ebs-csi-driver/main.tf

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

# Service account for EBS CSI driver
resource "kubernetes_service_account" "ebs_csi_driver" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.ebs_csi_driver_role.arn
    }
  }
}

# IAM role for EBS CSI driver
resource "aws_iam_role" "ebs_csi_driver_role" {
  name = "${var.project_tag}-${var.environment}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
            "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-${var.environment}-ebs-csi-driver-role"
    Purpose     = "ebs-csi-driver"
  }
}

# Attach EBS CSI driver policy
resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver_role.name
}

# Helm release for EBS CSI driver
resource "helm_release" "ebs_csi_driver" {
  name       = var.release_name
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = var.chart_version
  namespace  = var.namespace

  set = [
    {
      name  = "controller.serviceAccount.create"
      value = "false"
    },
    {
      name  = "controller.serviceAccount.name"
      value = var.service_account_name
    }
  ]

  depends_on = [kubernetes_service_account.ebs_csi_driver]
}
