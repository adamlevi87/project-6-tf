# modules/eks/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

locals {
  ecr_arn_list = values(var.ecr_repository_arns)
  
  # Create nodeadm config per node group
  nodeadm_configs = {
    for ng_name, ng_config in var.node_groups : ng_name => templatefile("${path.module}/nodeadm-config.yaml.tpl", {
      cluster_name        = aws_eks_cluster.main.name
      cluster_endpoint    = aws_eks_cluster.main.endpoint
      cluster_ca          = aws_eks_cluster.main.certificate_authority[0].data
      cluster_cidr        = aws_eks_cluster.main.kubernetes_network_config[0].service_ipv4_cidr
      nodegroup_name      = ng_name
      node_labels         = ng_config.labels
      node_taints         = ng_config.taints
    })
  }
  
  # Create user data per node group
  user_data_configs = {
    for ng_name, ng_config in var.node_groups : ng_name => <<-EOF
      MIME-Version: 1.0
      Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

      --==MYBOUNDARY==
      Content-Type: application/node.eks.aws

      ${local.nodeadm_configs[ng_name]}
      --==MYBOUNDARY==--
    EOF
  }

  # Create all node group security group IDs for cross-communication
  all_node_sg_ids = [for ng_name, ng_config in var.node_groups : aws_security_group.nodes[ng_name].id]

  # Create a flattened list of node group pairs for cross-communication
  # Create all possible pairs of node groups (excluding self-pairs)
  node_group_pairs = flatten([
    for ng1_name, ng1_config in var.node_groups : [
      for ng2_name, ng2_config in var.node_groups : {
        source = ng1_name
        target = ng2_name
      }
      if ng1_name != ng2_name
    ]
  ])
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
    Name        = "${var.project_tag}-${var.environment}-eks-node-group-role"
    Project     = var.project_tag
    Environment = var.environment
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
        Resource = local.ecr_arn_list
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

# Node group security groups - one per node group
resource "aws_security_group" "nodes" {
  for_each = var.node_groups

  name        = "${var.project_tag}-${var.environment}-eks-${each.key}-sg"
  description = "EKS worker node SG for ${each.key} node group"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_tag}-${var.environment}-eks-${each.key}-sg"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "eks-worker-nodes"
    NodeGroup   = each.key
  }
}

# Launch templates - one per node group
resource "aws_launch_template" "nodes" {
  for_each = var.node_groups

  name_prefix   = "${var.project_tag}-${var.environment}-eks-${each.key}-lt-"
  image_id      = each.value.ami_id
  instance_type = each.value.instance_type

  tag_specifications {
    resource_type = "volume"
    tags = {
      Project     = var.project_tag
      Environment = var.environment
      NodeGroup   = each.key
      "eks:cluster-name" = var.cluster_name
      "eks:nodegroup-name" = "${var.project_tag}-${var.environment}-${each.key}"
      Name        = "${var.project_tag}-${var.environment}-eks-${each.key}-volume"
    }
  }

  tag_specifications {
    resource_type = "network-interface"
    tags = {
      Project     = var.project_tag
      Environment = var.environment
      NodeGroup   = each.key
      "eks:cluster-name" = var.cluster_name
      "eks:nodegroup-name" = "${var.project_tag}-${var.environment}-${each.key}"
      Name        = "${var.project_tag}-${var.environment}-eks-${each.key}-eni"
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Project     = var.project_tag
      Environment = var.environment
      NodeGroup   = each.key
      "eks:cluster-name" = var.cluster_name
      "eks:nodegroup-name" = "${var.project_tag}-${var.environment}-${each.key}"
      Name        = "${var.project_tag}-${var.environment}-eks-${each.key}-node"
    }
  }

  # Per-node group user data
  user_data = base64encode(local.user_data_configs[each.key])

  network_interfaces {
    associate_public_ip_address = false
    security_groups              = [aws_security_group.nodes[each.key].id]
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"  # Forces IMDSv2
    http_put_response_hop_limit = 2
  }

  lifecycle {
    create_before_destroy = true
  }
}

# EKS Node Groups - one per configuration
resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_tag}-${var.environment}-${each.key}"
  node_role_arn   = aws_iam_role.node_group_role.arn
  subnet_ids      = var.private_subnet_ids

  launch_template {
    id      = aws_launch_template.nodes[each.key].id
    version = "$Latest"
  }

  scaling_config {
    desired_size = each.value.desired_capacity
    max_size     = each.value.max_capacity
    min_size     = each.value.min_capacity
  }

  update_config {
    max_unavailable = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  depends_on = [
    aws_iam_role_policy_attachment.node_group_worker_policy,
    aws_iam_role_policy_attachment.node_group_cni_policy,
    aws_iam_role_policy_attachment.node_group_registry_policy,
    aws_launch_template.nodes,
  ]

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    NodeGroup   = each.key
    Name        = "${var.project_tag}-${var.environment}-${each.key}"
    Purpose     = "kubernetes-nodes"
  }
}

# ================================
# SECURITY GROUP RULES - ORGANIZED & DOCUMENTED
# ================================

# ================================
# SECTION 1: CLUSTER ↔ NODE COMMUNICATION  
# Purpose: Enable essential EKS cluster control plane to communicate with worker nodes
# 
# NOTE: AWS automatically creates an egress rule on the cluster security group 
# allowing ALL outbound traffic (0.0.0.0/0, all ports, all protocols).
# Therefore, all "cluster_to_node_*" egress rules below are DOCUMENTATION ONLY
# but kept for explicit clarity of required EKS communication patterns.
# ================================

# ── CLUSTER to NODES (Egress from Cluster Security Group) ──

resource "aws_vpc_security_group_egress_rule" "cluster_to_node_kubelet" {
  for_each = var.node_groups

  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.nodes[each.key].id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  description                  = "REQUIRED: Cluster control plane to kubelet API on ${each.key} nodes"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "eks-essential"
    Rule    = "cluster-to-kubelet"
  }
}

resource "aws_vpc_security_group_egress_rule" "cluster_to_node_ephemeral" {
  for_each = var.node_groups

  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.nodes[each.key].id
  from_port                    = 1025
  to_port                      = 65535
  ip_protocol                  = "tcp"
  description                  = "REQUIRED: Cluster control plane to ephemeral ports on ${each.key} nodes (includes pod-to-pod via CNI)"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "eks-essential"
    Rule    = "cluster-to-ephemeral"
    Note    = "Covers kubelet(10250) and HTTPS(443) but kept separate for documentation"
  }
}

resource "aws_vpc_security_group_egress_rule" "cluster_to_node_https" {
  for_each = var.node_groups

  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.nodes[each.key].id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "DOCUMENTATION: Cluster control plane to HTTPS on ${each.key} nodes (covered by ephemeral rule but explicit for clarity)"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "documentation"
    Rule    = "cluster-to-https"
    Note    = "Redundant with ephemeral rule - kept for explicit documentation"
  }
}

# ── NODES to CLUSTER (Egress from Node Security Groups) ──

resource "aws_vpc_security_group_egress_rule" "node_to_cluster_api" {
  for_each = var.node_groups

  security_group_id            = aws_security_group.nodes[each.key].id
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "REQUIRED: ${each.key} nodes to cluster API server (authentication, API calls)"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "eks-essential"
    Rule    = "node-to-api"
  }
}

# ── CLUSTER ← NODES (Ingress to Cluster Security Group) ──

resource "aws_vpc_security_group_ingress_rule" "cluster_allow_node_api" {
  for_each = var.node_groups

  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.nodes[each.key].id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "REQUIRED: Allow ${each.key} nodes to cluster API server access"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "eks-essential"
    Rule    = "allow-node-to-api"
  }
}

# ── NODES ← CLUSTER (Ingress to Node Security Groups) ──

resource "aws_vpc_security_group_ingress_rule" "node_allow_cluster_kubelet" {
  for_each = var.node_groups

  security_group_id            = aws_security_group.nodes[each.key].id
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  description                  = "REQUIRED: Allow cluster control plane to kubelet on ${each.key} nodes"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "eks-essential"
    Rule    = "allow-cluster-to-kubelet"
  }
}

resource "aws_vpc_security_group_ingress_rule" "node_allow_cluster_ephemeral" {
  for_each = var.node_groups

  security_group_id            = aws_security_group.nodes[each.key].id
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port                    = 1025
  to_port                      = 65535
  ip_protocol                  = "tcp"
  description                  = "REQUIRED: Allow cluster control plane to ephemeral ports on ${each.key} nodes"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "eks-essential"
    Rule    = "allow-cluster-to-ephemeral"
  }
}

resource "aws_vpc_security_group_ingress_rule" "node_allow_cluster_https" {
  for_each = var.node_groups

  security_group_id            = aws_security_group.nodes[each.key].id
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "DOCUMENTATION: Allow cluster control plane to HTTPS on ${each.key} nodes (covered by ephemeral but explicit)"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "documentation"
    Rule    = "allow-cluster-to-https"
    Note    = "Redundant with ephemeral rule - kept for explicit documentation"
  }
}

# ================================
# SECTION 2: EXTERNAL ACCESS
# Purpose: Allow access from outside the VPC to cluster services
# ================================

resource "aws_vpc_security_group_ingress_rule" "eks_api_from_cidrs" {
  for_each = toset(var.eks_api_allowed_cidr_blocks)

  security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
  description       = "EXTERNAL: Allow kubectl/API access from ${each.value} (GitHub Actions, admin IPs)"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "external-access"
    Rule    = "api-from-cidr"
    Source  = each.value
  }
}

# ================================
# SECTION 3: INTRA-CLUSTER COMMUNICATION
# Purpose: Enable pod-to-pod communication within and across node groups
# This is what enables Kubernetes networking to function
# ================================

# ── SAME NODE GROUP COMMUNICATION ──

resource "aws_vpc_security_group_ingress_rule" "node_to_node_same_group" {
  for_each = var.node_groups

  security_group_id            = aws_security_group.nodes[each.key].id
  referenced_security_group_id = aws_security_group.nodes[each.key].id
  ip_protocol                  = "-1"  # All protocols
  description                  = "INTRA-GROUP: Allow all communication between nodes within ${each.key} group (pod-to-pod, service discovery)"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "kubernetes-networking"
    Rule    = "same-group-ingress"
    Scope   = each.key
  }
}

resource "aws_vpc_security_group_egress_rule" "node_to_node_same_group" {
  for_each = var.node_groups

  security_group_id            = aws_security_group.nodes[each.key].id
  referenced_security_group_id = aws_security_group.nodes[each.key].id
  ip_protocol                  = "-1"  # All protocols
  description                  = "INTRA-GROUP: Allow all communication from nodes within ${each.key} group"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "kubernetes-networking"
    Rule    = "same-group-egress"
    Scope   = each.key
  }
}

# ── CROSS NODE GROUP COMMUNICATION ──

resource "aws_vpc_security_group_ingress_rule" "cross_nodegroup_communication" {
  for_each = {
    for pair in local.node_group_pairs : "${pair.source}-to-${pair.target}" => pair
  }

  security_group_id            = aws_security_group.nodes[each.value.target].id
  referenced_security_group_id = aws_security_group.nodes[each.value.source].id
  ip_protocol                  = "-1"  # All protocols
  description                  = "CROSS-GROUP: Allow all communication from ${each.value.source} nodes to ${each.value.target} nodes (enables pod scheduling flexibility)"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "kubernetes-networking"
    Rule    = "cross-group-ingress"
    Source  = each.value.source
    Target  = each.value.target
  }
}

resource "aws_vpc_security_group_egress_rule" "cross_nodegroup_communication" {
  for_each = {
    for pair in local.node_group_pairs : "${pair.source}-to-${pair.target}" => pair
  }

  security_group_id            = aws_security_group.nodes[each.value.source].id
  referenced_security_group_id = aws_security_group.nodes[each.value.target].id
  ip_protocol                  = "-1"  # All protocols
  description                  = "CROSS-GROUP: Allow all communication from ${each.value.source} nodes to ${each.value.target} nodes"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "kubernetes-networking"
    Rule    = "cross-group-egress"
    Source  = each.value.source
    Target  = each.value.target
  }
}

# ================================
# SECTION 4: INTERNET ACCESS
# Purpose: Enable nodes to reach external services (AWS APIs, package repos, registries)
# REDUNDANCY NOTE: The 'all_outbound' rule makes most specific rules redundant,
# but we keep specific rules for documentation and future granular control
# ================================

# ── OPERATIONAL RULE: Broad Internet Access ──

resource "aws_vpc_security_group_egress_rule" "nodes_all_outbound" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "OPERATIONAL: Allow all outbound traffic from ${each.key} nodes (simplifies troubleshooting, covers all AWS APIs)"
  
  ip_protocol = "-1"  # All protocols
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name    = "${var.project_tag}-${var.environment}-${each.key}-all-outbound"
    Purpose = "operational-simplicity"
    Rule    = "all-outbound"
    Note    = "Makes specific rules below redundant but kept for documentation"
  }
}

# -- DOCUMENTATION RULES: Specific Services --
# These rules are COVERED by the all_outbound rule above but kept for:
# 1. Explicit documentation of what services nodes need
# 2. Future ability to remove all_outbound and use granular rules
# 3. Security audit clarity

resource "aws_vpc_security_group_egress_rule" "nodes_dns_udp" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "DOCUMENTATION: DNS resolution (UDP) from ${each.key} nodes to internet (covered by all_outbound)"
  
  ip_protocol = "udp"
  from_port   = 53
  to_port     = 53
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "documentation"
    Rule    = "dns-udp"
    Note    = "Redundant with all_outbound - kept for explicit documentation"
  }
}

resource "aws_vpc_security_group_egress_rule" "nodes_dns_tcp" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "DOCUMENTATION: DNS resolution (TCP) from ${each.key} nodes to internet (large queries, covered by all_outbound)"
  
  ip_protocol = "tcp"
  from_port   = 53
  to_port     = 53
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "documentation"
    Rule    = "dns-tcp"
    Note    = "Redundant with all_outbound - kept for explicit documentation"
  }
}

resource "aws_vpc_security_group_egress_rule" "nodes_https_outbound" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "DOCUMENTATION: HTTPS from ${each.key} nodes to AWS APIs, registries (covered by all_outbound)"
  
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "documentation"
    Rule    = "https-outbound"
    Note    = "Redundant with all_outbound - kept for explicit documentation"
  }
}

resource "aws_vpc_security_group_egress_rule" "nodes_http_outbound" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "DOCUMENTATION: HTTP from ${each.key} nodes to package repos, updates (covered by all_outbound)"
  
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "documentation"
    Rule    = "http-outbound"
    Note    = "Redundant with all_outbound - kept for explicit documentation"
  }
}

resource "aws_vpc_security_group_egress_rule" "nodes_ntp" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "DOCUMENTATION: NTP from ${each.key} nodes to time servers (covered by all_outbound)"
  
  ip_protocol = "udp"
  from_port   = 123
  to_port     = 123
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "documentation"
    Rule    = "ntp-outbound"
    Note    = "Redundant with all_outbound - kept for explicit documentation"
  }
}

resource "aws_vpc_security_group_egress_rule" "nodes_ephemeral_tcp" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "DOCUMENTATION: Ephemeral TCP ports from ${each.key} nodes to outbound connections (covered by all_outbound)"
  
  ip_protocol = "tcp"
  from_port   = 1024
  to_port     = 65535
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name    = "${var.project_tag}-${var.environment}-${each.key}-ephemeral-tcp"
    Purpose = "documentation"
    Rule    = "ephemeral-tcp"
    Note    = "Redundant with all_outbound - kept for explicit documentation"
  }
}

resource "aws_vpc_security_group_egress_rule" "nodes_custom_ports" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "DOCUMENTATION: Custom app ports from ${each.key} nodes to external services (covered by all_outbound)"
  
  ip_protocol = "tcp"
  from_port   = 8000
  to_port     = 8999
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name    = "${var.project_tag}-${var.environment}-${each.key}-custom-ports"
    Purpose = "documentation"
    Rule    = "custom-ports"
    Note    = "Redundant with all_outbound - kept for explicit documentation"
  }
}

# ================================
# SECURITY GROUP RULES SUMMARY
# ================================
# ESSENTIAL RULES (Required for EKS to function):
#   - cluster_to_node_kubelet / node_allow_cluster_kubelet
#   - cluster_to_node_ephemeral / node_allow_cluster_ephemeral  
#   - node_to_cluster_api / cluster_allow_node_api
#   - nodes_all_outbound (for AWS API access)
#   - cross_nodegroup_communication (for multi-nodegroup pod scheduling)
#
# DOCUMENTATION RULES (Redundant but kept for clarity):
#   - cluster_to_node_https / node_allow_cluster_https (covered by ephemeral)
#   - nodes_dns_* / nodes_https_outbound / nodes_http_outbound (covered by all_outbound)
#   - nodes_ephemeral_tcp / nodes_custom_ports (covered by all_outbound)
#
# EXTERNAL ACCESS:
#   - eks_api_from_cidrs (admin/CI access to cluster API)
#
# ARCHITECTURE DECISION:
# We use a layered approach with both broad rules (operational simplicity) 
# and specific rules (documentation/future granular control). This provides:
# 1. Operational reliability (broad rules ensure everything works)
# 2. Security documentation (specific rules show exactly what's needed)  
# 3. Future flexibility (can remove broad rules and use specific ones)
# ================================











# # Get the default node security group created by EKS
# data "aws_security_group" "node_group_sg" {
#   filter {
#     name   = "group-name"
#     values = ["eks-cluster-sg-${aws_eks_cluster.main.name}-*"]
#   }
  
#   filter {
#     name   = "tag:aws:eks:cluster-name"
#     values = [aws_eks_cluster.main.name]
#   }

#   filter {
#     name   = "vpc-id"
#     values = [var.vpc_id]
#   }
# }

# Cluster SG
# resource "aws_security_group" "eks_cluster" {
#   name        = "${var.project_tag}-${var.environment}-eks-cluster-sg"
#   description = "Custom EKS cluster security group"
#   vpc_id      = var.vpc_id

#   tags = {
#     Name        = "${var.project_tag}-${var.environment}-eks-cluster-sg"
#     Project     = var.project_tag
#     Environment = var.environment
#     Purpose     = "eks-cluster-api"
#   }
# }

# # Create IAM instance profile for the node group
# resource "aws_iam_instance_profile" "nodes" {
#   name = "${var.project_tag}-${var.environment}-eks-nodes-instance-profile"
#   role = aws_iam_role.node_group_role.name
  
#   tags = {
#     Name = "${var.project_tag}-${var.environment}-eks-nodes-instance-profile"
#   }
# }

# # Control Plane access to the nodes
# resource "aws_security_group_rule" "allow_cluster_to_nodes" {
#   type                     = "ingress"
#   from_port                = 1025
#   to_port                  = 65535
#   protocol                 = "tcp"
#   security_group_id        = aws_security_group.nodes.id
#   source_security_group_id = "sg-0a9d986ac63a06d9f"
#   description              = "Allow control plane to reach kubelet"
# }
