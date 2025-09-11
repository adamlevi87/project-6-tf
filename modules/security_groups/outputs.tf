# modules/security_groups/outputs.tf

output "joined_security_group_ids" {
  description = "a string of all the security group IDs separated by commas"
  value       = local.joined_security_group_ids
}
