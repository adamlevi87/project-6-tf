# terraform-main/modules/external-dns/main.tf

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

resource "helm_release" "this" {
  name       = "${var.release_name}"
  
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.chart_version
  
  namespace  = "${var.namespace}"
  create_namespace = false
  
  set = [
    {
      name  = "provider"
      value = "aws"
    },
    # changed to sync to support updating and deleting records
    {
      name  = "policy"
      value = "sync"
    },
    # {
    #   name  = "policy"
    #   value = "upsert-only"
    # },
    {
      name  = "txtOwnerId"
      value = var.txt_owner_id
    },
    {
      name  = "domainFilters[0]"
      value = var.domain_filter
    },
    {
      name  = "aws.zoneType"
      value = var.zone_type
    },
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = "${var.service_account_name}"
    }
  ]

  depends_on = [
    aws_iam_role_policy_attachment.this,
    kubernetes_service_account.this
  ]
}

resource "aws_iam_role" "this" {
  name = "${var.project_tag}-${var.environment}-external-dns"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
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
    }]
  })

  tags = {
    Name        = "${var.project_tag}-${var.environment}-external-dns"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "external-dns"
  }
}

resource "kubernetes_service_account" "this" {
  metadata {
    name      = "${var.service_account_name}"
    namespace = "${var.namespace}"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
    }
  }
}

# Custom IAM policy for ExternalDNS - zone-scoped permissions
resource "aws_iam_policy" "external_dns_custom" {
  name = "${var.project_tag}-${var.environment}-external-dns-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Global Route53 permissions (required for ExternalDNS to function)
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        # Specific hosted zone permissions - scoped to your zone only
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets",
          "route53:GetHostedZone"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/${var.hosted_zone_id}"
        ]
      }
    ]
  })

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-${var.environment}-external-dns-policy"
    Purpose     = "external-dns"
  }
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.external_dns_custom.arn
}
