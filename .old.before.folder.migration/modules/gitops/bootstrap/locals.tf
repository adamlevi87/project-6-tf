# modules/gitops/bootstrap/locals.tf

locals {
  # Generate branch name
  timestamp = formatdate("YYYY-MM-DD-hhmm", timestamp())
  branch_name = "${var.branch_name_prefix}-${var.environment}-${local.timestamp}"
  
  # Repository URLs
  app_repo_url    = "https://github.com/${var.github_org}/${var.github_application_repo}.git"
  gitops_repo_url = "https://github.com/${var.github_org}/${var.github_gitops_repo}.git"
  
  # File paths
  project_yaml_path          = "reference_only/${var.environment}/project/${var.project_tag}.yaml"
  app_of_apps_yaml_path      = "reference_only/${var.environment}/app_of_apps.yaml"
  frontend_infra_values_path = "environments/${var.environment}/manifests/frontend/infra-values.yaml"
  frontend_app_values_path   = "environments/${var.environment}/manifests/frontend/app-values.yaml"
  frontend_app_path          = "environments/${var.environment}/apps/frontend/application.yaml"
  
  # Template variables for ArgoCD project
  project_template_vars = {
    project_tag              = var.project_tag
    argocd_namespace         = var.argocd_namespace
    app_name                 = var.project_tag
    github_org               = var.github_org
    github_gitops_repo       = var.github_gitops_repo
    github_application_repo  = var.github_application_repo
  }

  # Template variables for frontend infra-values.yaml
  frontend_template_vars = {
    ecr_frontend_repo_url           = var.ecr_frontend_repo_url
    frontend_namespace              = var.frontend_namespace
    frontend_service_account_name   = var.frontend_service_account_name
    frontend_container_port         = var.frontend_container_port
    frontend_ingress_host           = var.frontend_ingress_host
    alb_group_name                  = var.alb_group_name
    alb_security_groups             = var.alb_security_groups
    acm_certificate_arn             = var.acm_certificate_arn
    frontend_external_dns_hostname  = var.frontend_external_dns_hostname
  }
  
  #Template variables for frontend Application.yaml
  frontend_app_template_vars = {
    app_name                  = var.frontend_argocd_app_name
    argocd_namespace          = var.argocd_namespace
    argocd_project_name       = var.project_tag
    app_namespace             = var.frontend_namespace
    app_repo_url              = local.app_repo_url
    helm_release_name         = var.frontend_helm_release_name
    environment               = var.environment
    github_org                = var.github_org
    github_gitops_repo        = var.github_gitops_repo
    github_application_repo   = var.github_application_repo
  }

  # Always render these for change detection
  rendered_frontend_infra       = templatefile("${path.module}/templates/frontend/infra-values.yaml.tpl", local.frontend_template_vars)
  
  # Bootstrap templates (only rendered in bootstrap mode)
  rendered_project                = var.bootstrap_mode ? var.argocd_project_yaml : ""
  rendered_app_of_apps            = var.bootstrap_mode ? var.argocd_app_of_apps_yaml : ""
  rendered_frontend_app           = var.bootstrap_mode ? templatefile("${path.module}/templates/application.yaml.tpl", local.frontend_app_template_vars) : ""
  rendered_frontend_app_values    = var.bootstrap_mode ? templatefile("${path.module}/templates/frontend/app-values.yaml.tpl", {}) : ""
}
