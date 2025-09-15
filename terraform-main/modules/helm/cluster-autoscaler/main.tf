# terraform-main/modules/cluster-autoscaler/main.tf

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
  
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = var.chart_version
  
  namespace  = "${var.namespace}"
  create_namespace = false

  set = [
    {
      name  = "autoDiscovery.clusterName"
      value = var.cluster_name
    },
    {
      name  = "rbac.serviceAccount.name"
      value = var.service_account_name
    },
    {
      name  = "rbac.serviceAccount.create"
      value = "false"
    },
    {
      name  = "extraArgs.balance-similar-node-groups"
      value = "true"
    },
    {
      name  = "extraArgs.skip-nodes-with-system-pods"
      value = "false"
    },
    {
      name  = "extraArgs.skip-nodes-with-local-storage"
      value = "false"
    }
  ]

  depends_on = [
    aws_iam_role_policy_attachment.this,
    kubernetes_service_account.this
  ]
}

resource "aws_iam_role" "this" {
  name = "${var.project_tag}-${var.environment}-cluster-autoscaler"
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
          "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
          "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "cluster-autoscaler"
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

resource "aws_iam_policy" "this" {
  name = "${var.project_tag}-${var.environment}-cluster-autoscaler-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        # These actions need * to discover and describe ASGs
        Effect = "Allow",
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances", 
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "ec2:DescribeLaunchTemplateVersions"
        ],
        Resource = "*"
      },
      {
        # These actions can be scoped to specific ASGs
        Effect = "Allow",
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ],
        Resource = var.autoscaling_group_arns
      }
    ]
  })
 
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "cluster-autoscaler"
  }
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}
