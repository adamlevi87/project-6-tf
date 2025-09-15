# modules/github/trigger-app-build/main.tf

resource "null_resource" "trigger_app_build" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Triggering app repo build for ${var.environment}..."
      curl -X POST \
        -H "Authorization: Bearer ${var.github_token}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${var.github_org}/${var.github_application_repo}/dispatches" \
        -d '{
          "event_type": "terraform-infrastructure-ready",
          "client_payload": {
            "environment": "${var.environment}",
            "trigger_source": "terraform"
          }
        }'
      echo "Build trigger sent for ${var.environment}"
    EOT
  }

  triggers = {
    # Trigger when any of these change
    environment = var.environment
    timestamp   = timestamp()
  }
}
