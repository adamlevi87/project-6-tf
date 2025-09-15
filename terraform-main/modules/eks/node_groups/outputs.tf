# terraform-main/modules/eks/node_groups/outputs.tf

output "autoscaling_group_arns" {
  description = "ARNs of Auto Scaling Groups for node groups"
  value = [
    for ng_name, ng in aws_eks_node_group.main : ng.resources[0].autoscaling_groups[0].name
  ]
}
