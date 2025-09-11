# modules/gitops-workflow/locals.tf

locals {
  # Generate branch name
  timestamp = formatdate("YYYY-MM-DD-hhmm", timestamp())
  branch_name = "${var.branch_name_prefix}-${var.environment}-${local.timestamp}"
  
  # Repository URLs
  app_repo_url    = "https://github.com/${var.github_org}/${var.github_application_repo}.git"
  gitops_repo_url = "https://github.com/${var.github_org}/${var.github_gitops_repo}.git"
  
  # File paths
  project_yaml_path          = "projects/${var.project_tag}.yaml"
  frontend_infra_values_path = "environments/${var.environment}/manifests/frontend/infra-values.yaml"
  frontend_app_values_path   = "environments/${var.environment}/manifests/frontend/app-values.yaml"
  # backend_infra_values_path  = "environments/${var.environment}/manifests/backend/infra-values.yaml"
  # backend_app_values_path    = "environments/${var.environment}/manifests/backend/app-values.yaml"
  frontend_app_path          = "environments/${var.environment}/apps/frontend/application.yaml"
  # backend_app_path           = "environments/${var.environment}/apps/backend/application.yaml"
  
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
    # frontend_external_secret_name   = var.frontend_external_secret_name
    # frontend_aws_secret_key         = var.frontend_aws_secret_key
    #project_tag                     = var.project_tag
    #environment                     = var.environment
    #aws_region                      = var.aws_region
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

  # # Template variables for backend infra-values.yaml
  # backend_template_vars = {
  #   ecr_backend_repo_url           = var.ecr_backend_repo_url
  #   backend_namespace              = var.backend_namespace
  #   backend_service_account_name   = var.backend_service_account_name
  #   backend_container_port         = var.backend_container_port
  #   backend_ingress_host           = var.backend_ingress_host
  #   alb_group_name                 = var.alb_group_name
  #   alb_security_groups            = var.alb_security_groups
  #   acm_certificate_arn            = var.acm_certificate_arn
  #   backend_external_dns_hostname  = var.backend_external_dns_hostname
  #   backend_external_secret_name   = var.backend_external_secret_name
  #   backend_aws_secret_key         = var.backend_aws_secret_key
  #   project_tag                     = var.project_tag
  #   environment                     = var.environment
  #   aws_region                     = var.aws_region
  # }
  
  # # Template variables for backend Application.yaml
  # backend_app_template_vars = {
  #   app_name                  = "backend"
  #   argocd_namespace          = var.argocd_namespace
  #   argocd_project_name       = var.project_tag
  #   app_namespace             = var.backend_namespace
  #   app_repo_url              = local.app_repo_url
  #   helm_release_name         = "backend"
  #   environment               = var.environment
  #   github_org                = var.github_org
  #   github_gitops_repo        = var.github_gitops_repo
  #   github_application_repo   = var.github_application_repo
  # }
  
  # Applications to create (for bootstrap mode)
  #applications = ["frontend", "backend"]

  # Always render these for change detection
  rendered_frontend_infra       = templatefile("${path.module}/templates/frontend/infra-values.yaml.tpl", local.frontend_template_vars)
  #rendered_backend_infra        = templatefile("${path.module}/templates/backend/infra-values.yaml.tpl", local.backend_template_vars)
  
  # Bootstrap templates (only rendered in bootstrap mode)
  #rendered_project              = var.bootstrap_mode ? templatefile("${path.module}/templates/project.yaml.tpl", local.project_template_vars) : ""
  rendered_frontend_app         = var.bootstrap_mode ? templatefile("${path.module}/templates/application.yaml.tpl", local.frontend_app_template_vars) : ""
  #rendered_backend_app          = var.bootstrap_mode ? templatefile("${path.module}/templates/application.yaml.tpl", local.backend_app_template_vars) : ""
  rendered_frontend_app_values  = var.bootstrap_mode ? templatefile("${path.module}/templates/frontend/app-values.yaml.tpl", {}) : ""
  #rendered_backend_app_values   = var.bootstrap_mode ? templatefile("${path.module}/templates/backend/app-values.yaml.tpl", {}) : ""

  rendered_content = merge(
    # Always include infra files
    {
      (local.frontend_infra_values_path) = local.rendered_frontend_infra
      #(local.backend_infra_values_path)  = local.rendered_backend_infra
    },
    # Conditionally include bootstrap files
    var.bootstrap_mode ? {
      #(local.project_yaml_path)          = local.rendered_project
      (local.frontend_app_path)          = local.rendered_frontend_app
      #(local.backend_app_path)           = local.rendered_backend_app
      (local.frontend_app_values_path)   = local.rendered_frontend_app_values
      #(local.backend_app_values_path)    = local.rendered_backend_app_values
    } : {}
  )

  # # Real change detection using data sources
  # changed_files = {
  #   for file_path, file_data in data.github_repository_file.current_files :
  #   file_path => try(
  #     file_data.content != base64encode(local.rendered_content[file_path]),
  #     true # If file doesn't exist, consider it changed
  #   )
  # }

  # changed_files = {
  #   for file_path, file_data in var.current_files_data :
  #   file_path => try(
  #     file_data.content != base64encode(local.rendered_content[file_path]),
  #     true
  #   )
  # }

  #has_changes = length([for changed in local.changed_files : changed if changed]) > 0
}
