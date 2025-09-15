# modules/eks/launch_templates/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

locals {
  # Create nodeadm config per node group
  nodeadm_configs = {
    for ng_name, ng_config in var.node_groups : ng_name => templatefile("${path.module}/nodeadm-config.yaml.tpl", {
      cluster_name        = var.cluster_name
      cluster_endpoint    = var.cluster_endpoint
      cluster_ca          = var.cluster_ca
      cluster_cidr        = var.cluster_cidr
      nodegroup_name      = ng_name
      node_labels         = ng_config.labels
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
    security_groups              = [var.node_security_group_ids[each.key]]
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
