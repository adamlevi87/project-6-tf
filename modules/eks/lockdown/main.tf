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
      echo "🔒 Triggering EKS lockdown workflow..."
      echo "Repository: ${var.github_org}/${var.github_repo}"
      echo "Security Group: ${var.cluster_security_group_id}"
      
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
        }' \
        -w "HTTP Status: %{http_code}\n" \
        -o /dev/null -s
      
      if [ $? -eq 0 ]; then
        echo "✅ EKS lockdown workflow API call completed"
      else
        echo "❌ Failed to trigger workflow"
        exit 1
      fi
    EOT
  }
  
  triggers = {
    cluster_sg_id = var.cluster_security_group_id
    environment   = var.environment
  }
}
