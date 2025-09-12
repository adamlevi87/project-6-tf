# modules/gitops/bootstrap/main.tf

terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.6.0"
    }
  }
}

resource "github_branch" "gitops_branch" { 
  repository = var.gitops_repo_name
  branch     = local.branch_name
  source_branch = var.target_branch
}

# Bootstrap files (only in bootstrap mode)
resource "github_repository_file" "bootstrap_files" {
  for_each = var.bootstrap_mode ? {
    "project"              = { path = local.project_yaml_path, content = local.rendered_project }
    "app_of_apps"          = { path = local.app_of_apps_yaml_path, content = local.rendered_app_of_apps }
    "frontend_application" = { path = local.frontend_app_path, content = local.rendered_frontend_app }
    # "backend_application"  = { path = local.backend_app_path, content = local.rendered_backend_app }
    "frontend_app_values"  = { path = local.frontend_app_values_path, content = local.rendered_frontend_app_values }
    # "backend_app_values"   = { path = local.backend_app_values_path, content = local.rendered_backend_app_values }
  } : {}
  
  repository = var.gitops_repo_name
  file       = each.value.path
  content    = each.value.content
  branch     = github_branch.gitops_branch.branch
  
  commit_message = "Bootstrap: Create ${each.key}"
  commit_author  = "Terraform GitOps"
  commit_email   = "terraform@gitops.local"
  
  overwrite_on_create = true
}

# Infrastructure files (bootstrap OR update mode)
resource "github_repository_file" "infra_files" {
  for_each = var.bootstrap_mode || var.update_apps ? {
    "frontend_infra" = { path = local.frontend_infra_values_path, content = local.rendered_frontend_infra }
    #"backend_infra"  = { path = local.backend_infra_values_path, content = local.rendered_backend_infra }
  } : {}
  
  repository = var.gitops_repo_name
  file       = each.value.path
  content    = each.value.content
  branch     = github_branch.gitops_branch.branch
  
  commit_message = var.bootstrap_mode ? "Bootstrap: Create ${each.key} values" : "Update: ${each.key} values for ${var.environment}"
  commit_author  = "Terraform GitOps"
  commit_email   = "terraform@gitops.local"
  
  overwrite_on_create = true
  depends_on = [
    github_repository_file.bootstrap_files
  ]
}

# Manage PR creation and cleanup entirely via local-exec
# Manage PR creation and cleanup entirely via local-exec
resource "null_resource" "manage_pr" {
  depends_on = [
    github_branch.gitops_branch,
    github_repository_file.bootstrap_files,
    github_repository_file.infra_files
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      #!/bin/bash
      set -e
      
      # Enhanced error handling
      cleanup_on_error() {
        echo "Error occurred. Cleaning up..."
        if [ -n "$BRANCH_NAME" ] && [ "$BRANCH_NAME" != "${var.target_branch}" ]; then
          echo "Attempting to delete branch: $BRANCH_NAME"
          curl -s -X DELETE \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/git/refs/heads/$BRANCH_NAME" || true
        fi
        exit 1
      }
      trap cleanup_on_error ERR
      
      # Variables
      GITHUB_TOKEN="${var.github_token}"
      REPO_OWNER="${var.github_org}"
      REPO_NAME="${var.github_gitops_repo}"
      BRANCH_NAME="${github_branch.gitops_branch.branch}"
      TARGET_BRANCH="${var.target_branch}"
      PR_TITLE="${var.bootstrap_mode ? "Bootstrap: ${var.project_tag} ${var.environment}" : "Update: ${var.environment} infrastructure"}"
      PR_BODY="${var.bootstrap_mode ? "Bootstrap GitOps configuration for ${var.project_tag}" : "Update infrastructure values for ${var.environment}"}"
      
      echo "=== GitHub PR Management ==="
      echo "REPO: $REPO_OWNER/$REPO_NAME"
      echo "BRANCH: $BRANCH_NAME"
      echo "TARGET: $TARGET_BRANCH"
      echo "MODE: ${var.bootstrap_mode ? "bootstrap" : "update"}"
      
      # Wait a moment for GitHub to process the branch creation
      echo "Waiting for GitHub to process branch creation..."
      sleep 5
      
      # Check if there are actual file changes
      echo "Checking for actual changes between branches..."
      COMPARE_RESPONSE=$(curl -s \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/compare/$TARGET_BRANCH...$BRANCH_NAME")
      
      # Check if API call was successful
      if echo "$COMPARE_RESPONSE" | jq -e '.message' >/dev/null 2>&1; then
        echo "GitHub API Error: $(echo "$COMPARE_RESPONSE" | jq -r '.message')"
        exit 1
      fi
      
      CHANGES=$(echo "$COMPARE_RESPONSE" | jq '.files | length')
      
      if [ "$CHANGES" = "0" ] || [ -z "$CHANGES" ]; then
        echo "No actual changes detected. Cleaning up branch and exiting."
        curl -s -X DELETE \
          -H "Authorization: token $GITHUB_TOKEN" \
          -H "Accept: application/vnd.github.v3+json" \
          "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/git/refs/heads/$BRANCH_NAME" || true
        exit 0
      fi
      
      echo "Found $CHANGES changed files. Proceeding with PR creation..."
      
      # Create PR with proper JSON escaping
      PR_RESPONSE=$(curl -s -w "HTTPSTATUS:%%{http_code}" \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls" \
        -d "$(jq -n \
          --arg title "$PR_TITLE" \
          --arg body "$PR_BODY" \
          --arg head "$BRANCH_NAME" \
          --arg base "$TARGET_BRANCH" \
          '{title: $title, body: $body, head: $head, base: $base}')")
      
      HTTP_CODE=$(echo "$PR_RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
      RESPONSE_BODY=$(echo "$PR_RESPONSE" | sed 's/HTTPSTATUS:[0-9]*$//')
      
      echo "HTTP Code: $HTTP_CODE"
      echo "Response: $RESPONSE_BODY"
      
      case "$HTTP_CODE" in
        200|201)
          PR_NUMBER=$(echo "$RESPONSE_BODY" | jq -r '.number')
          echo "✅ Created PR #$PR_NUMBER"
          
          if [ "${var.auto_merge_pr}" = "true" ]; then
            echo "🔀 Triggering auto-merge workflow..."
            
            # Create dispatch payload with proper escaping
            DISPATCH_PAYLOAD=$(jq -n \
              --arg event_type "auto-merge-pr" \
              --argjson pr_number "$PR_NUMBER" \
              '{event_type: $event_type, client_payload: {pr_number: $pr_number}}')
            
            DISPATCH_RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" \
              -H "Authorization: token $GITHUB_TOKEN" \
              -H "Accept: application/vnd.github.v3+json" \
              -H "Content-Type: application/json" \
              "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/dispatches" \
              -d "$DISPATCH_PAYLOAD")
            
            DISPATCH_CODE=$(echo "$DISPATCH_RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
            
            if [ "$DISPATCH_CODE" = "204" ]; then
              echo "✅ Auto-merge workflow triggered successfully"
            else
              echo "⚠️  Failed to trigger auto-merge (non-fatal). Code: $DISPATCH_CODE"
              echo "Response: $(echo "$DISPATCH_RESPONSE" | sed 's/HTTPSTATUS:[0-9]*$//')"
            fi
          fi
          ;;
        422)
          # Check if it's because PR already exists
          if echo "$RESPONSE_BODY" | grep -q "pull request already exists"; then
            echo "ℹ️  PR already exists between these branches"
            
            # Get existing PR number
            EXISTING_PR=$(curl -s \
              -H "Authorization: token $GITHUB_TOKEN" \
              -H "Accept: application/vnd.github.v3+json" \
              "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls?head=$REPO_OWNER:$BRANCH_NAME&base=$TARGET_BRANCH")
            
            PR_NUMBER=$(echo "$EXISTING_PR" | jq -r '.[0].number')
            if [ "$PR_NUMBER" != "null" ]; then
              echo "Found existing PR #$PR_NUMBER"
            fi
          else
            echo "❌ Failed to create PR. Response: $RESPONSE_BODY"
            exit 1
          fi
          ;;
        *)
          echo "❌ Failed to create PR. HTTP Code: $HTTP_CODE"
          echo "Response: $RESPONSE_BODY"
          exit 1
          ;;
      esac
      
      echo "🎉 PR management completed successfully"
    EOT
  }

  # Clean up branch on destroy
  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      echo "Cleaning up branch: ${self.triggers.branch_name}"
      curl -s -X DELETE \
        -H "Authorization: token ${self.triggers.github_token}" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/${self.triggers.github_org}/${self.triggers.github_gitops_repo}/git/refs/heads/${self.triggers.branch_name}" || true
    EOT
  }

  # Store values for destroy-time cleanup
  triggers = {
    branch_name          = github_branch.gitops_branch.branch
    github_token        = var.github_token
    github_org          = var.github_org
    github_gitops_repo  = var.github_gitops_repo
    # Force recreation when files change
    bootstrap_files_hash = var.bootstrap_mode ? join(",", [for k, v in github_repository_file.bootstrap_files : "${k}:${filemd5(v.file)}"]  ) : ""
    infra_files_hash    = var.bootstrap_mode || var.update_apps ? join(",", [for k, v in github_repository_file.infra_files : "${k}:${filemd5(v.file)}"]) : ""
  }
}
