# modules/gitops/bootstrap/main.tf

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

resource "null_resource" "gitops_bootstrap" {
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
#!/bin/bash
set -e

# Variables
GITHUB_TOKEN="${var.github_token}"
GITHUB_ORG="${var.github_org}"
GITOPS_REPO="${var.github_gitops_repo}"
TARGET_BRANCH="${var.target_branch}"
BRANCH_NAME="${local.branch_name}"

echo "=== GitOps Bootstrap ==="
echo "Repo: $GITHUB_ORG/$GITOPS_REPO"
echo "Branch: $BRANCH_NAME"
echo "Mode: ${var.bootstrap_mode ? "bootstrap" : "update"}"

# Clone the GitOps repository
echo "Cloning GitOps repository..."
rm -rf gitops-repo
git clone "https://x-access-token:$GITHUB_TOKEN@github.com/$GITHUB_ORG/$GITOPS_REPO.git" gitops-repo
cd gitops-repo

# Configure git
git config user.name "Terraform GitOps"
git config user.email "terraform@gitops.local"

# Track if any files actually changed
CHANGES_MADE=false

# Function to update file if content differs
update_file_if_changed() {
  local file_path="$1"
  local new_content="$2"
  local file_description="$3"
  
  echo "Checking $file_description..."
  
  # Create directory if it doesn't exist
  mkdir -p "$(dirname "$file_path")"
  
  # Compare content
  if [ ! -f "$file_path" ]; then
    echo "  File doesn't exist, creating..."
    echo "$new_content" > "$file_path"
    CHANGES_MADE=true
  elif ! echo "$new_content" | diff -q "$file_path" - > /dev/null 2>&1; then
    echo "  Content differs, updating..."
    echo "$new_content" > "$file_path"
    CHANGES_MADE=true
  else
    echo "  No changes needed"
  fi
}

# Bootstrap files (only in bootstrap mode)
if [ "${var.bootstrap_mode}" = "true" ]; then
  echo "=== Bootstrap Mode Files ==="
  
  # Project YAML (reference only)
  cat > /tmp/content1 << 'TERRAFORM_EOF'
${local.rendered_project}
TERRAFORM_EOF
  update_file_if_changed "${local.project_yaml_path}" "$(cat /tmp/content1)" "ArgoCD Project"
  
  # App of Apps YAML (reference only)
  cat > /tmp/content2 << 'TERRAFORM_EOF'
${local.rendered_app_of_apps}
TERRAFORM_EOF
  update_file_if_changed "${local.app_of_apps_yaml_path}" "$(cat /tmp/content2)" "App of Apps"
  
  # Frontend Application YAML
  cat > /tmp/content3 << 'TERRAFORM_EOF'
${local.rendered_frontend_app}
TERRAFORM_EOF
  update_file_if_changed "${local.frontend_app_path}" "$(cat /tmp/content3)" "Frontend Application"
  
  # Frontend App Values YAML
  cat > /tmp/content4 << 'TERRAFORM_EOF'
${local.rendered_frontend_app_values}
TERRAFORM_EOF
  update_file_if_changed "${local.frontend_app_values_path}" "$(cat /tmp/content4)" "Frontend App Values"
fi

# Infrastructure files (bootstrap OR update mode)
if [ "${var.bootstrap_mode}" = "true" ] || [ "${var.update_apps}" = "true" ]; then
  echo "=== Infrastructure Files ==="
  
  # Frontend Infrastructure Values
  cat > /tmp/content5 << 'TERRAFORM_EOF'
${local.rendered_frontend_infra}
TERRAFORM_EOF
  update_file_if_changed "${local.frontend_infra_values_path}" "$(cat /tmp/content5)"
fi

# Check if any changes were made
if [ "$CHANGES_MADE" = "false" ]; then
  echo "No changes detected. Exiting without creating PR."
  cd ..
  rm -rf gitops-repo
  exit 0
fi

echo "Changes detected. Creating PR..."

# Create branch and commit changes
git checkout -b "$BRANCH_NAME"
git add .

# Create commit message
if [ "${var.bootstrap_mode}" = "true" ]; then
  COMMIT_MSG="Bootstrap: ${var.project_tag} ${var.environment} GitOps configuration"
else
  COMMIT_MSG="Update: ${var.environment} infrastructure values"
fi

git commit -m "$COMMIT_MSG"
git push origin "$BRANCH_NAME"

# Create PR
echo "Creating PR..."
if [ "${var.bootstrap_mode}" = "true" ]; then
  PR_TITLE="Bootstrap: ${var.project_tag} ${var.environment}"
  PR_BODY="Bootstrap GitOps configuration for ${var.project_tag} ${var.environment}"
else
  PR_TITLE="Update: ${var.environment} infrastructure"
  PR_BODY="Update infrastructure values for ${var.environment}"
fi

PR_RESPONSE=$(curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$GITHUB_ORG/$GITOPS_REPO/pulls" \
  -d "{\"title\":\"$PR_TITLE\",\"body\":\"$PR_BODY\",\"head\":\"$BRANCH_NAME\",\"base\":\"$TARGET_BRANCH\"}")

# Extract PR number
PR_NUMBER=$(echo "$PR_RESPONSE" | grep '"number"' | head -1 | sed 's/.*"number": *\([0-9]*\).*/\1/')

if [ -n "$PR_NUMBER" ] && [ "$PR_NUMBER" -gt 0 ] 2>/dev/null; then
  echo "✅ Created PR #$PR_NUMBER"
  
  # Trigger auto-merge if enabled
  if [ "${var.auto_merge_pr}" = "true" ]; then
    echo "Triggering auto-merge..."
    curl -X POST \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/$GITHUB_ORG/$GITOPS_REPO/dispatches" \
      -d "{\"event_type\":\"auto-merge-pr\",\"client_payload\":{\"pr_number\":$PR_NUMBER}}"
    echo "✅ Auto-merge triggered"
  fi
else
  echo "❌ Failed to create PR"
  echo "Response: $PR_RESPONSE"
  exit 1
fi

# Cleanup
cd ..
rm -rf gitops-repo

echo "🎉 GitOps bootstrap completed successfully"
    EOT
  }
}
