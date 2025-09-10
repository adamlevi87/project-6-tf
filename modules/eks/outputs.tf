# modules/eks/outputs.tf

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "oidc_provider_arn" {
  description = "The OIDC provider ARN for IRSA"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "autoscaling_group_arns" {
  description = "ARNs of Auto Scaling Groups for node groups"
  value = { 
    for ng_name, ng in aws_eks_node_group.main : ng_name => ng.resources[0].autoscaling_groups[0].name 
  }
}

output "node_group_security_group_ids" {
  description = "Map of node group names to their security group IDs"
  value       = { for ng_name, ng in aws_security_group.nodes : ng_name => ng.id }
}

# output "cluster_id" {
#   description = "EKS cluster ID"
#   value       = aws_eks_cluster.main.id
# }

# output "cluster_arn" {
#   description = "EKS cluster ARN"
#   value       = aws_eks_cluster.main.arn
# }

# output "cluster_endpoint" {
#   description = "EKS cluster endpoint"
#   value       = aws_eks_cluster.main.endpoint
# }

# output "cluster_version" {
#   description = "EKS cluster Kubernetes version"
#   value       = aws_eks_cluster.main.version
# }

# output "cluster_security_group_id" {
#   description = "Security group ID attached to the EKS cluster"
#   value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
# }

# output "node_group_names" {
#   description = "Map of node group names to their full resource names"
#   value       = { for ng_name, ng in aws_eks_node_group.main : ng_name => ng.node_group_name }
# }

# output "node_group_arns" {
#   description = "Map of node group names to their ARNs"
#   value       = { for ng_name, ng in aws_eks_node_group.main : ng_name => ng.arn }
# }

# output "node_group_role_arn" {
#   value       = aws_iam_role.node_group_role.arn
#   description = "IAM role ARN for the EKS node groups (shared)"
# }

# output "node_group_statuses" {
#   description = "Map of node group names to their statuses"
#   value       = { for ng_name, ng in aws_eks_node_group.main : ng_name => ng.status }
# }


# output "cluster_primary_security_group_id" {
#   description = "The cluster primary security group ID created by EKS"
#   value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
# }

# output "cluster_certificate_authority_data" {
#   value = aws_eks_cluster.main.certificate_authority[0].data
# }

# # Debug output for nodeadm configs per node group
# output "debug_nodeadm_configs" {
#   value = local.nodeadm_configs
# }
