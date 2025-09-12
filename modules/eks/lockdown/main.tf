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
    command = "/bin/bash"
    interpreter = ["/bin/bash", "-c"]
    
    environment = {
      GITHUB_TOKEN = var.github_token
      GITHUB_ORG   = var.github_org
      GITHUB_REPO  = var.github_repo
      CLUSTER_SG   = var.cluster_security_group_id
      ENVIRONMENT  = var.environment
    }
    
    # Use a separate script to avoid template parsing issues
    stdin = <<-SCRIPT
      set -x  # Enable debug output
      
      echo "=== DEBUG: Starting EKS Lockdown Trigger ==="
      echo "GitHub Org: $GITHUB_ORG"
      echo "GitHub Repo: $GITHUB_REPO"
      echo "Security Group: $CLUSTER_SG"
      echo "Environment: $ENVIRONMENT"
      
      # Create temp file for response
      RESPONSE_FILE="/tmp/github_response_$$.txt"
      
      echo "=== Making API Call ==="
      curl -v -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -o "$RESPONSE_FILE" \
        -w "\nHTTP_STATUS:%{http_code}\n" \
        "https://api.github.com/repos/$GITHUB_ORG/$GITHUB_REPO/actions/workflows/lockdown-eks.yml/dispatches" \
        -d "{
          \"ref\": \"main\",
          \"inputs\": {
            \"cluster_security_group_id\": \"$CLUSTER_SG\",
            \"trigger_source\": \"terraform\"
          }
        }" 2>&1
      
      echo "=== Response File Contents ==="
      cat "$RESPONSE_FILE"
      
      echo "=== Checking HTTP Status ==="
      if grep -q "HTTP_STATUS:204" "$RESPONSE_FILE"; then
        echo "✅ SUCCESS: Workflow dispatch accepted (HTTP 204)"
      else
        echo "❌ FAILED: Check response above"
        cat "$RESPONSE_FILE"
        exit 1
      fi
      
      # Clean up
      rm -f "$RESPONSE_FILE"
      
      echo "=== Workflow should now be visible at: ==="
      echo "https://github.com/$GITHUB_ORG/$GITHUB_REPO/actions"
    SCRIPT
  }
  
  triggers = {
    cluster_sg_id = var.cluster_security_group_id
    environment   = var.environment
    timestamp     = timestamp()  # Force run every time for debugging
  }
}