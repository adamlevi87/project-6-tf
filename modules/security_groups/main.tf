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

# SG to be applied onto the ALB (happens when argoCD creates the Shared ALB)
resource "aws_security_group" "alb_frontend" {
  name        = "${var.project_tag}-${var.environment}-frontend-sg"
  description = "Security group for frontend"
  vpc_id      = var.vpc_id

  # Allow Frontend access from the outside
  # 80 will be redirected to 443 later on (argocd module)
  dynamic "ingress" {
    for_each = [80, 443]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Frontend access on port ${ingress.value}"
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
    Name        = "${var.project_tag}-${var.environment}-frontend-sg"
    Purpose     = "frontend-security"
  }
}

resource "aws_security_group_rule" "allow_alb_to_frontend_pods" {
  for_each = var.node_group_security_groups

  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = each.value
  source_security_group_id = aws_security_group.alb_frontend.id
  description              = "Allow ALB to access Frontend pods on port 80 (${each.key} nodes)"
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
