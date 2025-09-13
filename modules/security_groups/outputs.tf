# modules/security_groups/outputs.tf

output "joined_security_group_ids" {
  description = "a string of all the security group IDs separated by commas"
  value       = local.joined_security_group_ids
}

output "eks_node_security_group_ids" {
  description = "Map of node group names to their security group IDs (for launch templates)"
  value       = { for ng_name, sg in aws_security_group.nodes : ng_name => sg.id }
}

output "joined_security_group_ids" {
  description = "a string of all the security group IDs separated by commas"
  value       = "${aws_security_group.alb_argocd.id},${aws_security_group.alb_frontend.id},${aws_security_group.alb_prometheus.id}"
}
