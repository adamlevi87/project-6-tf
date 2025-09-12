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
resource "terraform_data" "trigger_eks_lockdown" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "🔒 Triggering EKS lockdown workflow..."
      
      curl -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${var.github_token}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/repos/${var.github_org}/${var.github_repo}/actions/workflows/lockdown-eks.yml/dispatches \
        -d '{
          "ref": "main",
          "inputs": {
            "cluster_security_group_id": "${var.cluster_security_group_id}",
            "aws_region": "${var.aws_region}",
            "environment": "${var.environment}",
            "trigger_source": "terraform"
          }
        }'
      
      echo "✅ EKS lockdown workflow triggered successfully"
    EOT
    
    environment = {
      GITHUB_TOKEN = var.github_token
    }
  }
  
  # Optional: Add a small delay to ensure workflow starts
  provisioner "local-exec" {
    command = "sleep 5"
  }
}