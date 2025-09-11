# modules/gitops-workflow/main.tf

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
resource "null_resource" "manage_pr" {
  depends_on = [
    github_branch.gitops_branch,
    github_repository_file.bootstrap_files,
    github_repository_file.infra_files
  ]

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      # Variables
      GITHUB_TOKEN="${var.github_token}"
      REPO_OWNER="${var.github_org}"
      REPO_NAME="${var.github_gitops_repo}"
      BRANCH_NAME="${github_branch.gitops_branch.branch}"
      TARGET_BRANCH="${var.target_branch}"
      PR_TITLE="${var.bootstrap_mode ? "Bootstrap: ${var.project_tag} ${var.environment}" : "Update: ${var.environment} infrastructure"}"
      PR_BODY="${var.bootstrap_mode ? "Bootstrap GitOps configuration for ${var.project_tag}" : "Update infrastructure values for ${var.environment}"}"
      

      # Add at the start of local-exec script:
      exec > /tmp/tf-gitops-debug.log 2>&1
      echo "=== PR Management Debug Log - $(date) ==="
      echo "BRANCH_NAME: $BRANCH_NAME"
      echo "REPO_NAME: $REPO_NAME" 
      echo "Variables passed: bootstrap_mode=${var.bootstrap_mode}, update_apps=${var.update_apps}"
      
      echo "Attempting to create PR from $BRANCH_NAME to $TARGET_BRANCH..."
      
      # Create JSON payload properly using jq
      JSON_PAYLOAD=$(jq -n \
        --arg title "$PR_TITLE" \
        --arg body "$PR_BODY" \
        --arg head "$BRANCH_NAME" \
        --arg base "$TARGET_BRANCH" \
        '{title: $title, body: $body, head: $head, base: $base}')
      
      # Try to create PR - store response and HTTP code separately
      HTTP_CODE=$(curl -s -o /tmp/pr_response.json -w "%%{http_code}" \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls" \
        -d "$JSON_PAYLOAD")
      
      PR_DATA=$(cat /tmp/pr_response.json)
      
      if [ "$HTTP_CODE" = "422" ]; then
        echo "No commits between branches - cleaning up empty branch..."
        
        # Delete the empty branch
        echo "Deleting branch $BRANCH_NAME..."
        DELETE_CODE=$(curl -s -o /dev/null -w "%%{http_code}" \
          -X DELETE \
          -H "Authorization: token $GITHUB_TOKEN" \
          -H "Accept: application/vnd.github.v3+json" \
          "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/git/refs/heads/$BRANCH_NAME")
        
        if [[ "$DELETE_CODE" =~ ^(200|204)$ ]]; then
          echo "Empty branch deleted successfully"
          
          # Remove branch from Terraform state - NOTE: This will fail due to state lock
          # terraform state rm github_branch.gitops_branch
          echo "Branch removed from GitHub. Terraform state will be corrected on next run."
        else
          echo "Failed to delete branch (HTTP: $DELETE_CODE)" >&2
          exit 1
        fi
        
      elif [[ "$HTTP_CODE" =~ ^(200|201)$ ]]; then
        echo "PR created successfully"
        
        # Extract PR number
        PR_NUMBER=$(echo "$PR_DATA" | jq -r '.number')
        echo "PR #$PR_NUMBER created"
        
        # Check if PR has actual file changes
        echo "Checking PR #$PR_NUMBER for file changes..."
        CHANGED_FILES=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
          "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls/$PR_NUMBER/files" | \
          jq length)
        
        echo "PR #$PR_NUMBER has $CHANGED_FILES file changes"
        
        if [ "$CHANGED_FILES" -eq 0 ]; then
          echo "No file changes detected - cleaning up empty PR and branch..."
          
          # Close the PR
          echo "Closing PR #$PR_NUMBER..."
          curl -s -X PATCH \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls/$PR_NUMBER" \
            -d '{"state":"closed"}'
          
          # Delete the branch
          echo "Deleting branch $BRANCH_NAME..."
          curl -s -X DELETE \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/git/refs/heads/$BRANCH_NAME"
          
          # Remove branch from Terraform state - NOTE: This will fail due to state lock  
          # terraform state rm github_branch.gitops_branch
          echo "Empty PR and branch cleaned up from GitHub. Terraform state will be corrected on next run."
        else
          echo "PR has meaningful changes - leaving PR #$PR_NUMBER open"
        fi
        
      else
        echo "Failed to create PR (HTTP: $HTTP_CODE)" >&2
        echo "Response: $PR_DATA" >&2
        exit 1
      fi
    EOT
  }

  # Trigger when branch changes
  triggers = {
    branch_name = github_branch.gitops_branch.branch
  }
}