# modules/eks/cluster/outputs.tf

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

output "cluster_security_group_id" {
  description = "Security group ID of the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca" {
  description = "EKS cluster certificate authority data"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_cidr" {
  description = "EKS cluster service IPv4 CIDR"
  value       = aws_eks_cluster.main.kubernetes_network_config[0].service_ipv4_cidr
}

# # output for eks readyness (for providers: kubectl/helm/kubernetes)
# output "kubectl_access_ready_resource" {
#   description = "Resource that only exists when 0.0.0.0/0 is present in public_access_cidrs (position independent)"
#   value = length(null_resource.kubectl_access_ready) > 0 ? null_resource.kubectl_access_ready[0] : null
# }
