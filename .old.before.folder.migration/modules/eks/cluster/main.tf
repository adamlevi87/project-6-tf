# modules/eks/cluster/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

# EKS Cluster IAM Role
resource "aws_iam_role" "cluster_role" {
  name = "${var.project_tag}-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-${var.environment}-eks-cluster-role"
    Purpose     = "eks-cluster"
  }
}

# Attach required policies to cluster role
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster_role.name
}

# CloudWatch Log Group for EKS cluster
resource "aws_cloudwatch_log_group" "cluster_logs" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_days

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-${var.environment}-eks-logs"
    Purpose     = "eks-logging"
  }
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster_role.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    # These might be temporary until Github runners is moved into the VPC
    endpoint_public_access  = true
    public_access_cidrs     = var.eks_api_allowed_cidr_blocks
  }

  enabled_cluster_log_types = var.cluster_enabled_log_types != null ? var.cluster_enabled_log_types : []

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_cloudwatch_log_group.cluster_logs
  ]

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = var.cluster_name
    Purpose     = "kubernetes-cluster"
  }
}

# # Resource that only exists when 0.0.0.0/0 is present ANYWHERE in the CIDR list
# resource "null_resource" "kubectl_access_ready" {
#   count = contains(aws_eks_cluster.main.vpc_config[0].public_access_cidrs, "0.0.0.0/0") ? 1 : 0
  
#   provisioner "local-exec" {
#     command = "echo '✅ EKS cluster has 0.0.0.0/0 access - kubectl operations can proceed'"
#   }
  
#   triggers = {
#     cluster_name = aws_eks_cluster.main.name
#     vpc_config_hash = jsonencode(aws_eks_cluster.main.vpc_config[0].public_access_cidrs)
#   }
# }

# Get OIDC issuer certificate
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# IAM OIDC provider for the cluster
resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-${var.environment}-eks-oidc"
    Purpose     = "eks-oidc-provider"
  }
}
