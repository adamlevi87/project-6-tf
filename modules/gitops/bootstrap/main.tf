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
      
      # Variables
      GITHUB_TOKEN="${var.github_token}"
      REPO_OWNER="${var.github_org}"
      REPO_NAME="${var.github_gitops_repo}"
      BRANCH_NAME="${github_branch.gitops_branch.branch}"
      TARGET_BRANCH="${var.target_branch}"
      PR_TITLE="${var.bootstrap_mode ? "Bootstrap: ${var.project_tag} ${var.environment}" : "Update: ${var.environment} infrastructure"}"
      PR_BODY="${var.bootstrap_mode ? "Bootstrap GitOps configuration for ${var.project_tag}" : "Update infrastructure values for ${var.environment}"}"
      
      echo "=== Creating PR ==="
      echo "BRANCH_NAME: $BRANCH_NAME"
      echo "TARGET_BRANCH: $TARGET_BRANCH"
      
      # Create JSON payload
      JSON_PAYLOAD=$(jq -n \
        --arg title "$PR_TITLE" \
        --arg body "$PR_BODY" \
        --arg head "$BRANCH_NAME" \
        --arg base "$TARGET_BRANCH" \
        '{title: $title, body: $body, head: $head, base: $base}')
      
      echo "JSON_PAYLOAD: $JSON_PAYLOAD"
      
      # Try to create PR
      HTTP_CODE=$(curl -s -o /tmp/pr_response.json -w "%%{http_code}" \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls" \
        -d "$JSON_PAYLOAD")
      
      echo "HTTP_CODE: $HTTP_CODE"
      echo "Response: $(cat /tmp/pr_response.json)"
      
      if [ "$HTTP_CODE" = "422" ]; then
        echo "No changes to create PR for"
        exit 0
      elif [[ "$HTTP_CODE" =~ ^(200|201)$ ]]; then
        PR_NUMBER=$(cat /tmp/pr_response.json | jq -r '.number')
        echo "Created PR #$PR_NUMBER"
        
        if [ "${var.auto_merge_pr}" = "true" ]; then
          echo "Triggering auto-merge..."
          curl -X POST \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/dispatches" \
            -d "{\"event_type\":\"auto-merge-pr\",\"client_payload\":{\"pr_number\":$PR_NUMBER}}"
        fi
      else
        echo "Failed to create PR. HTTP Code: $HTTP_CODE"
        cat /tmp/pr_response.json
        exit 1
      fi
    EOT
  }

  # Trigger when branch changes
  triggers = {
    branch_name = github_branch.gitops_branch.branch
  }
}
