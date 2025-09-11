# modules/eks/cluster/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

# locals {
#   ecr_arn_list = values(var.ecr_repository_arns)
# }

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
    Name        = "${var.project_tag}-${var.environment}-eks-cluster-role"
    Project     = var.project_tag
    Environment = var.environment
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

# # EKS Node Group IAM Role
# resource "aws_iam_role" "node_group_role" {
#   name = "${var.project_tag}-${var.environment}-eks-node-group-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         }
#       }
#     ]
#   })

#   tags = {
#     Project     = var.project_tag
#     Environment = var.environment
#     Name        = "${var.project_tag}-${var.environment}-eks-node-group-role"
#     Purpose     = "eks-nodes"
#   }
# }

# resource "aws_iam_role_policy" "ecr_pull" {
#   name = "ecr-pull"
#   role = aws_iam_role.node_group_role.name

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       # Get token- Registery level against your AWS account
#       # Resource must be set to wildcard (*)
#       {
#         Effect = "Allow",
#         Action = [
#           "ecr:GetAuthorizationToken"
#         ],
#         Resource = "*"
#       },
#       {
#         Effect = "Allow",
#         Action = [
#           "ecr:BatchCheckLayerAvailability",
#           "ecr:GetDownloadUrlForLayer",
#           "ecr:BatchGetImage"
#         ],
#         Resource = local.ecr_arn_list
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "node_group_ssm" {
#   role       = aws_iam_role.node_group_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }

# resource "aws_iam_role_policy_attachment" "node_group_worker_policy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
#   role       = aws_iam_role.node_group_role.name
# }

# resource "aws_iam_role_policy_attachment" "node_group_cni_policy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
#   role       = aws_iam_role.node_group_role.name
# }

# resource "aws_iam_role_policy_attachment" "node_group_registry_policy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
#   role       = aws_iam_role.node_group_role.name
# }

# # Node group security groups - one per node group
# resource "aws_security_group" "nodes" {
#   for_each = var.node_groups

#   name        = "${var.project_tag}-${var.environment}-eks-${each.key}-sg"
#   description = "EKS worker node SG for ${each.key} node group"
#   vpc_id      = var.vpc_id

#   tags = {
#     Name        = "${var.project_tag}-${var.environment}-eks-${each.key}-sg"
#     Project     = var.project_tag
#     Environment = var.environment
#     Purpose     = "eks-worker-nodes"
#     NodeGroup   = each.key
#   }
# }

# # Launch templates - one per node group
# resource "aws_launch_template" "nodes" {
#   for_each = var.node_groups

#   name_prefix   = "${var.project_tag}-${var.environment}-eks-${each.key}-lt-"
#   image_id      = each.value.ami_id
#   instance_type = each.value.instance_type

#   tag_specifications {
#     resource_type = "volume"
#     tags = {
#       Project     = var.project_tag
#       Environment = var.environment
#       NodeGroup   = each.key
#       "eks:cluster-name" = var.cluster_name
#       "eks:nodegroup-name" = "${var.project_tag}-${var.environment}-${each.key}"
#       Name        = "${var.project_tag}-${var.environment}-eks-${each.key}-volume"
#     }
#   }

#   tag_specifications {
#     resource_type = "network-interface"
#     tags = {
#       Project     = var.project_tag
#       Environment = var.environment
#       NodeGroup   = each.key
#       "eks:cluster-name" = var.cluster_name
#       "eks:nodegroup-name" = "${var.project_tag}-${var.environment}-${each.key}"
#       Name        = "${var.project_tag}-${var.environment}-eks-${each.key}-eni"
#     }
#   }

#   tag_specifications {
#     resource_type = "instance"
#     tags = {
#       Project     = var.project_tag
#       Environment = var.environment
#       NodeGroup   = each.key
#       "eks:cluster-name" = var.cluster_name
#       "eks:nodegroup-name" = "${var.project_tag}-${var.environment}-${each.key}"
#       Name        = "${var.project_tag}-${var.environment}-eks-${each.key}-node"
#     }
#   }

#   # Per-node group user data
#   user_data = base64encode(local.user_data_configs[each.key])

#   network_interfaces {
#     associate_public_ip_address = false
#     security_groups              = [var.node_security_group_ids[each.key]]
#   }

#   metadata_options {
#     http_endpoint = "enabled"
#     http_tokens   = "required"  # Forces IMDSv2
#     http_put_response_hop_limit = 2
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# # EKS Node Groups - one per configuration
# resource "aws_eks_node_group" "main" {
#   for_each = var.node_groups

#   cluster_name    = aws_eks_cluster.main.name
#   node_group_name = "${var.project_tag}-${var.environment}-${each.key}"
#   node_role_arn   = aws_iam_role.node_group_role.arn
#   subnet_ids      = var.private_subnet_ids

#   launch_template {
#     id      = aws_launch_template.nodes[each.key].id
#     version = "$Latest"
#   }

#   scaling_config {
#     desired_size = each.value.desired_capacity
#     max_size     = each.value.max_capacity
#     min_size     = each.value.min_capacity
#   }

#   update_config {
#     max_unavailable = 1
#   }

#   # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
#   depends_on = [
#     aws_iam_role_policy_attachment.node_group_worker_policy,
#     aws_iam_role_policy_attachment.node_group_cni_policy,
#     aws_iam_role_policy_attachment.node_group_registry_policy,
#     aws_launch_template.nodes,
#   ]

#   tags = {
#     Project     = var.project_tag
#     Environment = var.environment
#     NodeGroup   = each.key
#     Name        = "${var.project_tag}-${var.environment}-${each.key}"
#     Purpose     = "kubernetes-nodes"
#   }
# }
