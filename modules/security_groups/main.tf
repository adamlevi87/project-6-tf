# modules/security_groups/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

locals {
  joined_security_group_ids = "${aws_security_group.alb_argocd.id},${aws_security_group.alb_frontend.id}"
}

# Frontend
# SG to be applied onto the ALB (happens when argoCD creates the Shared ALB)
resource "aws_security_group" "alb_frontend" {
  name        = "${var.project_tag}-${var.environment}-frontend-sg"
  description = "Security group for frontend"
  vpc_id      = var.vpc_id

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-${var.environment}-frontend-sg"
    Purpose     = "frontend-security"
  }
}

# Allow Frontend access from the outside
# 80 will be redirected to 443 later on
resource "aws_vpc_security_group_ingress_rule" "alb_frontend_http" {
  security_group_id = aws_security_group.alb_frontend.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Frontend access on port 80"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "frontend-security"
    Rule        = "http-ingress"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_frontend_https" {
  security_group_id = aws_security_group.alb_frontend.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Frontend access on port 443"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "frontend-security"
    Rule        = "https-ingress"
  }
}

# Outbound rules (usually not needed but good practice)
resource "aws_vpc_security_group_egress_rule" "alb_frontend_all_outbound" {
  security_group_id = aws_security_group.alb_frontend.id
  from_port         = 0
  to_port           = 0
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "All outbound traffic"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "frontend-security"
    Rule        = "all-outbound"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_alb_to_frontend_pods" {
  for_each = aws_security_group.nodes

  security_group_id            = each.value
  referenced_security_group_id = aws_security_group.alb_frontend.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Allow ALB to access Frontend pods on port 80 (${each.key} nodes)"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "frontend-security"
    Rule        = "alb-to-pods"
    NodeGroup   = each.key
  }
}

# ArgoCD
# SG to be applied onto the ALB (happens when argoCD creates the Shared ALB)
resource "aws_security_group" "alb_argocd" {
  name        = "${var.project_tag}-${var.environment}-argocd-sg"
  description = "Security group for argocd"
  vpc_id      = var.vpc_id

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-${var.environment}-argocd-sg"
    Purpose     = "argocd-security"
  }
}

# Allow ArgoCD access from the outside
# 80 will be redirected to 443 (controlled via argocd values file values.yaml.tpl ingress section)
resource "aws_vpc_security_group_ingress_rule" "alb_argocd_http" {
  security_group_id = aws_security_group.alb_argocd.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = var.argocd_allowed_cidr_blocks[0]
  description       = "ArgoCD access on port 80"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "argocd-security"
    Rule        = "http-ingress"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_argocd_https" {
  security_group_id = aws_security_group.alb_argocd.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = var.argocd_allowed_cidr_blocks[0]
  description       = "ArgoCD access on port 443"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "argocd-security"
    Rule        = "https-ingress"
  }
}

# Outbound rules (usually not needed but good practice)
resource "aws_vpc_security_group_egress_rule" "alb_argocd_all_outbound" {
  security_group_id = aws_security_group.alb_argocd.id
  from_port         = 0
  to_port           = 0
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "All outbound traffic"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "argocd-security"
    Rule        = "all-outbound"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_alb_to_argocd_pods" {
  for_each = aws_security_group.nodes

  security_group_id            = each.value
  referenced_security_group_id = aws_security_group.alb_argocd.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  description                  = "Allow ALB to access ArgoCD pods on port 8080 (${each.key} nodes)"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "argocd-security"
    Rule        = "alb-to-pods"
    NodeGroup   = each.key
  }
}



# ================================
# SECURITY GROUP & Rules - EKS - ORGANIZED & DOCUMENTED
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

