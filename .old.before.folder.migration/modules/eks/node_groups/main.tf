# modules/eks/node_groups/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

data "aws_launch_template" "latest" {
  for_each = var.node_groups
  id       = var.launch_template_ids[each.key]
}

# EKS Node Group IAM Role
resource "aws_iam_role" "node_group_role" {
  name = "${var.project_tag}-${var.environment}-eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-${var.environment}-eks-node-group-role"
    Purpose     = "eks-nodes"
  }
}

resource "aws_iam_role_policy" "ecr_pull" {
  name = "ecr-pull"
  role = aws_iam_role.node_group_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Get token- Registery level against your AWS account
      # Resource must be set to wildcard (*)
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ],
        Resource = var.ecr_repository_arns
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "node_group_ssm" {
  role       = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "node_group_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_group_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_group_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group_role.name
}

# EKS Node Groups - one per configuration
resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  cluster_name    = var.cluster_name
  node_group_name = "${var.project_tag}-${var.environment}-${each.key}"
  node_role_arn   = aws_iam_role.node_group_role.arn
  subnet_ids      = var.private_subnet_ids

  launch_template {
    id      = var.launch_template_ids[each.key]
    #version = "$Latest"
    version = data.aws_launch_template.latest[each.key].latest_version
  }

  scaling_config {
    desired_size = each.value.desired_capacity
    max_size     = each.value.max_capacity
    min_size     = each.value.min_capacity
  }

  lifecycle {
    ignore_changes = [
      scaling_config[0].desired_size,
      launch_template[0].version
    ]
  }

  update_config {
    max_unavailable = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  depends_on = [
    aws_iam_role_policy_attachment.node_group_worker_policy,
    aws_iam_role_policy_attachment.node_group_cni_policy,
    aws_iam_role_policy_attachment.node_group_registry_policy
  ]

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    NodeGroup   = each.key
    Name        = "${var.project_tag}-${var.environment}-${each.key}"
    Purpose     = "kubernetes-nodes"
  }
}
