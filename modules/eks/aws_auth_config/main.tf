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
  
  # Merge existing roles with new roles (new roles take precedence)
  merged_map_roles = concat(local.existing_map_roles, var.map_roles)
  merged_map_users = concat(local.existing_map_users, [
    for user_key, user in var.eks_user_access_map : {
      userarn  = user.userarn
      username = user.username
      groups   = user.groups
    }
  ])
}

resource "null_resource" "aws_auth_patch" {
  # Triggers rerun the block only when the variable changes
  triggers = {
    merged_roles = yamlencode(local.merged_map_roles)
    merged_users = yamlencode(local.merged_map_users)
  }

  provisioner "local-exec" {
  command = <<-EOT
    # Wait for aws-auth configmap to exist (created by node groups)
    echo "Waiting for aws-auth configmap to be created by EKS node groups..."
    for i in {1..30}; do
      if kubectl get configmap aws-auth -n kube-system >/dev/null 2>&1; then
        echo "aws-auth configmap found, proceeding with patch..."
        break
      fi
      echo "Attempt $i: aws-auth configmap not found, waiting 10 seconds..."
      sleep 10
    done
    
    # Update kubeconfig for EKS
    aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}
    
    # Apply the merged configmap
    kubectl patch configmap aws-auth -n kube-system --type merge -p '{
      "data": {
        "mapRoles": ${jsonencode(yamlencode(local.merged_map_roles))},
        "mapUsers": ${jsonencode(yamlencode(local.merged_map_users))}
      }
    }'
  EOT
  }
}
