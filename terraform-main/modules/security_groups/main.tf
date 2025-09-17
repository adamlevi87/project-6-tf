# terraform-main/modules/security_groups/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

resource "null_resource" "validate_peering_outputs" {
  #count = var.initialize_run ? 0 : 1
  
  provisioner "local-exec" {
    command = <<-EOF
      if [ "${var.runner_vpc_cidr}" = "10.255.255.0/24" ]; then
        echo "ERROR: Required runner_vpc_cidr missing" 
        exit 1
      fi
      echo "✅ All peering outputs validated"
    EOF
  }
}

locals {
  joined_security_group_ids = "${aws_security_group.alb_argocd.id},${aws_security_group.alb_frontend.id},${aws_security_group.alb_prometheus.id},${aws_security_group.alb_grafana.id}"
  
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

  security_group_id            = each.value.id
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
# SG to be applied onto the ALB
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
  for_each = toset(var.argocd_allowed_cidr_blocks)

  security_group_id = aws_security_group.alb_argocd.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
  description       = "ArgoCD access on port 80 from ${each.value}"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "argocd-security"
    Rule        = "http-ingress"
    Source      = each.value
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_argocd_https" {
  for_each = toset(var.argocd_allowed_cidr_blocks)

  security_group_id = aws_security_group.alb_argocd.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
  description       = "ArgoCD access on port 443 from ${each.value}"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "argocd-security" 
    Rule        = "https-ingress"
    Source      = each.value
  }
}

# Outbound rules (usually not needed but good practice)
resource "aws_vpc_security_group_egress_rule" "alb_argocd_all_outbound" {
  security_group_id = aws_security_group.alb_argocd.id
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

  security_group_id            = each.value.id
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

# Prometheus/Grafana
# SG to be applied onto the ALB
resource "aws_security_group" "alb_prometheus" {
  name        = "${var.project_tag}-${var.environment}-prometheus-sg"
  description = "Security group for Prometheus"
  vpc_id      = var.vpc_id

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-${var.environment}-prometheus-sg"
    Purpose     = "prometheus-security"
  }
}

# Allow Prometheus access from specified IPs only
# 80 will be redirected to 443 (controlled via ingress configuration)
resource "aws_vpc_security_group_ingress_rule" "alb_prometheus_http" {
  for_each = toset(var.prometheus_allowed_cidr_blocks)

  security_group_id = aws_security_group.alb_prometheus.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
  description       = "Prometheus access on port 80 from ${each.value}"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "prometheus-security"
    Rule        = "http-ingress"
    Source      = each.value
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_prometheus_https" {
  for_each = toset(var.prometheus_allowed_cidr_blocks)

  security_group_id = aws_security_group.alb_prometheus.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
  description       = "Prometheus access on port 443 from ${each.value}"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "prometheus-security"
    Rule        = "https-ingress" 
    Source      = each.value
  }
}

# Outbound rules (usually not needed but good practice)
resource "aws_vpc_security_group_egress_rule" "alb_prometheus_all_outbound" {
  security_group_id = aws_security_group.alb_prometheus.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "All outbound traffic"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "prometheus-security"
    Rule        = "all-outbound"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_alb_to_prometheus_pods" {
  for_each = aws_security_group.nodes

  security_group_id            = each.value.id
  referenced_security_group_id = aws_security_group.alb_prometheus.id
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
  description                  = "Allow ALB to access Grafana pods on port 3000 (${each.key} nodes)"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "prometheus-security"
    Rule        = "alb-to-pods"
    NodeGroup   = each.key
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_alb_to_prometheus_server_pods" {
  for_each = aws_security_group.nodes

  security_group_id            = each.value.id
  referenced_security_group_id = aws_security_group.alb_prometheus.id
  from_port                    = 9090
  to_port                      = 9090
  ip_protocol                  = "tcp"
  description                  = "Allow ALB to access Prometheus server pods on port 9090 (${each.key} nodes)"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "prometheus-security"
    Rule        = "alb-to-pods"
    NodeGroup   = each.key
  }
}

# Grafana
# SG to be applied onto the ALB
resource "aws_security_group" "alb_grafana" {
  name        = "${var.project_tag}-${var.environment}-grafana-sg"
  description = "Security group for grafana"
  vpc_id      = var.vpc_id

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-${var.environment}-grafana-sg"
    Purpose     = "grafana-security"
  }
}

# Allow Grafana access from the outside
resource "aws_vpc_security_group_ingress_rule" "alb_grafana_http" {
  for_each = toset(var.grafana_allowed_cidr_blocks)

  security_group_id = aws_security_group.alb_grafana.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
  description       = "Grafana access on port 80"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "grafana-security"
    Rule        = "http-ingress"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_grafana_https" {
  for_each = toset(var.grafana_allowed_cidr_blocks)

  security_group_id = aws_security_group.alb_grafana.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
  description       = "Grafana access on port 443"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "grafana-security"
    Rule        = "https-ingress"
  }
}

resource "aws_vpc_security_group_egress_rule" "alb_grafana_all_outbound" {
  security_group_id = aws_security_group.alb_grafana.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "All outbound traffic"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "grafana-security"
    Rule        = "all-outbound"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_alb_to_grafana_pods" {
  for_each = aws_security_group.nodes

  security_group_id            = each.value.id
  referenced_security_group_id = aws_security_group.alb_grafana.id
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
  description                  = "Allow ALB to access Grafana pods on port 3000 (${each.key} nodes)"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "grafana-security"
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

# ── CLUSTER to NODES (Egress from Cluster Security Group) ──

resource "aws_vpc_security_group_egress_rule" "cluster_to_node_kubelet" {
  for_each = var.node_groups

  security_group_id            = var.cluster_security_group_id
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

  security_group_id            = var.cluster_security_group_id
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

  security_group_id            = var.cluster_security_group_id
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
  referenced_security_group_id = var.cluster_security_group_id
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

  security_group_id            = var.cluster_security_group_id
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
  referenced_security_group_id = var.cluster_security_group_id
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
  referenced_security_group_id = var.cluster_security_group_id
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
  referenced_security_group_id = var.cluster_security_group_id
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

  security_group_id = var.cluster_security_group_id
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

resource "aws_vpc_security_group_ingress_rule" "eks_api_from_github_runner" {
  
  security_group_id = var.cluster_security_group_id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = var.runner_vpc_cidr
  description       = "PEERING: Allow Peered network - github runner- access to the cluster API"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "external-access"
    Rule    = "api-from-cidr"
    Source  = "Github-Runner-VPC-CIDR"
  }

  depends_on = [ null_resource.validate_peering_outputs ]
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
