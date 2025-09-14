# modules/eks/aws_auth_config/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38.0"
    }
  }
}
#
# Read existing aws-auth configmap to preserve node group roles
data "kubernetes_config_map_v1" "existing_aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
}

locals {
  # Parse existing mapRoles
  existing_map_roles = try(yamldecode(data.kubernetes_config_map_v1.existing_aws_auth.data["mapRoles"]), [])
  existing_map_users = try(yamldecode(data.kubernetes_config_map_v1.existing_aws_auth.data["mapUsers"]), [])
  
  # Get unique role ARNs and user ARNs from existing configmap
  existing_role_arns = toset([for role in local.existing_map_roles : role.rolearn])
  existing_user_arns = toset([for user in local.existing_map_users : user.userarn])
  
  # Only add new roles that don't already exist
  new_roles = [
    for role in var.map_roles : role 
    if !contains(local.existing_role_arns, role.rolearn)
  ]
  
  # Only add new users that don't already exist  
  new_users = [
    for user_key, user in var.eks_user_access_map : {
      userarn  = user.userarn
      username = user.username
      groups   = user.groups
    } if !contains(local.existing_user_arns, user.userarn)
  ]
  
  # Merge existing + new (no duplicates)
  merged_map_roles = concat(local.existing_map_roles, local.new_roles)
  merged_map_users = concat(local.existing_map_users, local.new_users)
}

resource "kubernetes_config_map_v1_data" "aws_auth_patch" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(local.merged_map_roles)
    mapUsers = yamlencode(local.merged_map_users)
  }

  force = true
  
  depends_on = [data.kubernetes_config_map_v1.existing_aws_auth]
}
