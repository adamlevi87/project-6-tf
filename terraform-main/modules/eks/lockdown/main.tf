# terraform-main/modules/eks/lockdown/main.tf

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
    command = "bash"
    
    environment = {
      GITHUB_TOKEN = var.github_token
      GITHUB_ORG   = var.github_org
      GITHUB_REPO  = var.github_repo
      CLUSTER_SG   = var.cluster_security_group_id
    }
    
    interpreter = ["bash", "-c", <<-BASH
      echo "=== Triggering EKS Lockdown ==="
      echo "Org: $GITHUB_ORG"
      echo "Repo: $GITHUB_REPO"
      echo "SG: $CLUSTER_SG"
      
      # Make the API call and capture everything
      OUTPUT=$(curl -s -v -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/$GITHUB_ORG/$GITHUB_REPO/actions/workflows/lockdown-eks.yml/dispatches" \
        -d '{"ref":"main","inputs":{"cluster_security_group_id":"'$CLUSTER_SG'","trigger_source":"terraform"}}' 2>&1)
      
      echo "=== CURL OUTPUT ==="
      echo "$OUTPUT"
      
      # Check if we got the success response
      if echo "$OUTPUT" | grep -q "< HTTP/2 204"; then
        echo "✅ SUCCESS: Workflow triggered"
      else
        echo "❌ FAILED: Check output above"
        exit 1
      fi
    BASH
    ]
  }
  
  triggers = {
    cluster_sg_id = var.cluster_security_group_id
    environment   = var.environment
    timestamp     = timestamp()  # Force run for debugging
  }
}
