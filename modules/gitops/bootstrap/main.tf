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
        set -euo pipefail

        DEBUG=${DEBUG:-false}
        if [[ "$DEBUG" == "true" ]]; then
          set -x
        fi

        # Small helper to exit cleanly after printing a message
        fail() { echo "❌ $*" >&2; exit 1; }

        # curl helper that returns body and http code (stored in global vars)
        http_request() {
          local method=$1 url=$2 data=${3:-}
          if [[ -n "$data" ]]; then
            response=$(curl -sS -w "HTTPSTATUS:%{http_code}" -X "$method" \
              -H "Authorization: token $GITHUB_TOKEN" \
              -H "Accept: application/vnd.github.v3+json" \
              -H "Content-Type: application/json" \
              -d "$data" \
              "$url")
          else
            response=$(curl -sS -w "HTTPSTATUS:%{http_code}" -X "$method" \
              -H "Authorization: token $GITHUB_TOKEN" \
              -H "Accept: application/vnd.github.v3+json" \
              "$url")
          fi
          HTTP_CODE=$(echo "$response" | sed -n 's/.*HTTPSTATUS:\([0-9]*\)$/\1/p')
          RESPONSE_BODY=$(echo "$response" | sed 's/HTTPSTATUS:[0-9]*$//')
        }

        # cleanup handler: delete branch if we created it and it's not the target
        cleanup_on_error() {
          local branch="$BRANCH_NAME"
          echo "Error occurred. Attempting cleanup..."
          if [[ -n "$branch" && "$branch" != "$TARGET_BRANCH" ]]; then
            echo "Deleting branch: $branch"
            http_request DELETE "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/git/refs/heads/$branch" || true
            echo "Delete HTTP code: $HTTP_CODE"
          fi
          exit 1
        }
        trap cleanup_on_error ERR

        # ---- Variables injected by Terraform ----
        GITHUB_TOKEN="${var.github_token}"
        REPO_OWNER="${var.github_org}"
        REPO_NAME="${var.github_gitops_repo}"    # NOTE: ensure this matches the repo var you use elsewhere
        BRANCH_NAME="${github_branch.gitops_branch.branch}"
        TARGET_BRANCH="${var.target_branch}"
        PR_TITLE="${var.bootstrap_mode ? "Bootstrap: ${var.project_tag} ${var.environment}" : "Update: ${var.environment} infrastructure"}"
        PR_BODY="${var.bootstrap_mode ? "Bootstrap GitOps configuration for ${var.project_tag}" : "Update infrastructure values for ${var.environment}"}"

        echo "=== GitHub PR Management ==="
        echo "REPO: $REPO_OWNER/$REPO_NAME"
        echo "BRANCH: $BRANCH_NAME"
        echo "TARGET: $TARGET_BRANCH"
        echo "MODE: ${var.bootstrap_mode ? "bootstrap" : "update"}"

        # Give GitHub a moment to process the branch
        sleep 3

        # 1) Compare branches to see if there are changes
        COMPARE_URL="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/compare/$TARGET_BRANCH...$BRANCH_NAME"
        http_request GET "$COMPARE_URL"

        if [[ "$HTTP_CODE" -ge 400 ]]; then
          echo "GitHub compare API returned HTTP $HTTP_CODE"
          echo "Body: $RESPONSE_BODY"
          fail "Compare failed"
        fi

        # Count files changed safely (if 'files' missing treat as 0)
        CHANGES=$(echo "$RESPONSE_BODY" | jq -r '.files? | length // 0')
        echo "Files changed: $CHANGES"

        if [[ "$CHANGES" -eq 0 ]]; then
          echo "No changes detected; deleting branch and exiting gracefully"
          http_request DELETE "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/git/refs/heads/$BRANCH_NAME" || true
          echo "Delete HTTP code: $HTTP_CODE"
          exit 0
        fi

        echo "Proceeding to create PR (found $CHANGES changed files)..."

        # 2) Create the PR
        PR_PAYLOAD=$(jq -n \
          --arg title "$PR_TITLE" \
          --arg body "$PR_BODY" \
          --arg head "$BRANCH_NAME" \
          --arg base "$TARGET_BRANCH" \
          '{title: $title, body: $body, head: $head, base: $base}')
        http_request POST "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls" "$PR_PAYLOAD"

        echo "Create PR HTTP $HTTP_CODE"
        echo "Response: $RESPONSE_BODY"

        case "$HTTP_CODE" in
          200|201)
            PR_NUMBER=$(echo "$RESPONSE_BODY" | jq -r '.number')
            echo "✅ Created PR #$PR_NUMBER"
            ;;
          422)
            # PR already exists? fetch it
            if echo "$RESPONSE_BODY" | jq -r '.message // empty' | grep -qi "pull request already exists"; then
              echo "PR already exists between these branches, fetching existing PR number..."
              http_request GET "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls?head=$REPO_OWNER:$BRANCH_NAME&base=$TARGET_BRANCH"
              if [[ "$HTTP_CODE" -eq 200 ]]; then
                PR_NUMBER=$(echo "$RESPONSE_BODY" | jq -r '.[0].number // empty')
                echo "Found existing PR #$PR_NUMBER"
              else
                echo "Failed to list PRs; HTTP $HTTP_CODE"
                fail "Could not fetch existing PR"
              fi
            else
              fail "Failed to create PR: HTTP $HTTP_CODE - $RESPONSE_BODY"
            fi
            ;;
          *)
            fail "Failed to create PR: HTTP $HTTP_CODE - $RESPONSE_BODY"
            ;;
        esac

        # 3) Optionally trigger auto-merge workflow via repository dispatch
        if [[ "${var.auto_merge_pr}" == "true" ]]; then
          echo "Triggering auto-merge workflow for PR #$PR_NUMBER..."
          DISPATCH_PAYLOAD=$(jq -n --arg event_type "auto-merge-pr" --argjson pr_number "$PR_NUMBER" '{event_type: $event_type, client_payload: {pr_number: $pr_number}}')
          http_request POST "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/dispatches" "$DISPATCH_PAYLOAD"
          if [[ "$HTTP_CODE" -eq 204 ]]; then
            echo "✅ Auto-merge workflow dispatched"
          else
            echo "⚠️  Dispatch HTTP $HTTP_CODE; body: $RESPONSE_BODY"
            # do not fatal here — non-fatal
          fi
        fi

        echo "🎉 PR management completed successfully"
 
    EOT
  }

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
