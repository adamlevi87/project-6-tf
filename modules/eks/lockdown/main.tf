# modules/eks/lockdown/main.tf

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# Trigger GitHub workflow to lockdown EKS access
resource "null_resource" "trigger_eks_lockdown" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Triggering EKS lockdown workflow..."
      curl -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${var.github_token}" \
        https://api.github.com/repos/${var.github_org}/${var.github_repo}/actions/workflows/lockdown-eks.yml/dispatches \
        -d '{
          "ref": "main",
          "inputs": {
            "cluster_security_group_id": "${var.cluster_security_group_id}",
            "trigger_source": "terraform"
          }
        }'
      echo "EKS lockdown workflow trigger sent"
    EOT
  }
  
  triggers = {
    cluster_sg_id = var.cluster_security_group_id
    environment   = var.environment
  }
}
