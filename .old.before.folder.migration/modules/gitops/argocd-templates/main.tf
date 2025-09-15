# modules/gitops/argocd-templates/main.tf

locals {
  # Template variables for project and app-of-apps
  template_vars = {
    project_tag                 = var.project_tag
    argocd_namespace            = var.argocd_namespace
    github_org                  = var.github_org
    github_gitops_repo          = var.github_gitops_repo
    github_application_repo     = var.github_application_repo
    environment                 = var.environment
    app_of_apps_path            = var.app_of_apps_path
    app_of_apps_target_revision = var.app_of_apps_target_revision
  }
}
