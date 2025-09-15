# terraform-main/modules/eks/launch_templates/outputs.tf

output "launch_template_ids" {
  description = "Map of node group names to their launch template IDs"
  value       = { for ng_name, template in aws_launch_template.nodes : ng_name => template.id }
}
