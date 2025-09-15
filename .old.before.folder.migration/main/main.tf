# main/main.tf

module "vpc" {
    source = "../modules/vpc"

    project_tag   = var.project_tag
    environment   = var.environment

    vpc_cidr_block = var.vpc_cidr_block
    nat_mode = var.nat_mode
   
    # Pass separated primary and additional subnet CIDRs
    # Primary Public
    primary_public_subnet_cidrs = {
        for az, pair in local.primary_subnet_pairs : az => pair.public_cidr
    }
    # Additional Public
    additional_public_subnet_cidrs = {
        for az, pair in local.additional_subnet_pairs : az => pair.public_cidr
    }
    # Private - all subnets
    private_subnet_cidrs = local.private_subnet_cidrs
}

module "kms" {
  source = "../modules/kms"

  project_tag = var.project_tag
  environment = var.environment

  account_id  = local.account_id

  # KMS configuration
  deletion_window_in_days = var.environment == "prod" ? 30 : 7
  enable_key_rotation     = true
}

module "s3" {
  source = "../modules/s3"
  
  project_tag   = var.project_tag
  environment   = var.environment

  # KMS encryption
  kms_key_arn = module.kms.kms_key_arn
  
  s3_policy_deny_rule_name = var.s3_policy_deny_rule_name
  #account_id = local.account_id

  allowed_principals = concat(
    local.s3_allowed_principal_arns,
    [module.frontend.iam_role_arn]
)
  
  # Lifecycle configuration
  enable_lifecycle_policy = true
  data_retention_days     = var.environment == "prod" ? 0 : 365  # Keep prod data forever, dev/staging for 1 year

  # Allow force destroy for non-prod environments
  force_destroy = var.environment != "prod"

  depends_on = [module.kms]
}

module "ecr" {
  source = "../modules/ecr"

  project_tag  = var.project_tag
  environment = var.environment
  
  ecr_repository_name = var.ecr_repository_name
  ecr_repositories_applications = var.ecr_repositories_applications
}

module "route53" {
  source       = "../modules/route53"

  project_tag  = var.project_tag
  environment  = var.environment
  
  domain_name    = var.domain_name
}

module "acm" {
  source           = "../modules/acm"

  project_tag      = var.project_tag
  environment      = var.environment

  cert_domain_name  = "*.${var.subdomain_name}.${var.domain_name}"
  route53_zone_id  = module.route53.zone_id
}

module "eks" {
  source = "../modules/eks/cluster"
  
  project_tag = var.project_tag
  environment = var.environment

  # Cluster configuration
  cluster_name        = "${var.project_tag}-${var.environment}-cluster"
  kubernetes_version  = var.eks_kubernetes_version
  
  # Networking (from VPC module)
  private_subnet_ids   = module.vpc.private_subnet_ids
  eks_api_allowed_cidr_blocks  = var.eks_api_allowed_cidr_blocks
  
  # Logging
  cluster_enabled_log_types = var.cluster_enabled_log_types
  cluster_log_retention_days = var.eks_log_retention_days
}

module "security_groups" {
  source = "../modules/security_groups"

  project_tag        = var.project_tag
  environment        = var.environment

  vpc_id = module.vpc.vpc_id

  # Security
  argocd_allowed_cidr_blocks      = var.argocd_allowed_cidr_blocks
  eks_api_allowed_cidr_blocks     = var.eks_api_allowed_cidr_blocks
  prometheus_allowed_cidr_blocks  = var.prometheus_allowed_cidr_blocks
  grafana_allowed_cidr_blocks     = var.grafana_allowed_cidr_blocks
  cluster_security_group_id       = module.eks.cluster_security_group_id
  
  # Node group configuration
  node_groups = var.eks_node_groups
}

module "launch_templates" {
  source = "../modules/eks/launch_templates"

  project_tag        = var.project_tag
  environment        = var.environment

  # Node group configuration
  node_groups = var.eks_node_groups

  cluster_name     = module.eks.cluster_name
  cluster_endpoint = module.eks.cluster_endpoint
  cluster_ca       = module.eks.cluster_ca
  cluster_cidr     = module.eks.cluster_cidr
  node_security_group_ids = module.security_groups.eks_node_security_group_ids
}

module "node_groups" {
  source = "../modules/eks/node_groups"

  project_tag        = var.project_tag
  environment        = var.environment

  # ECR for nodegroup permissions
  ecr_repository_arns = values(module.ecr.ecr_repository_arns)

  # Node group configuration
  node_groups = var.eks_node_groups

  cluster_name     = module.eks.cluster_name
  private_subnet_ids   = module.vpc.private_subnet_ids
  launch_template_ids =  module.launch_templates.launch_template_ids
}


module "aws_auth_config" {
  source = "../modules/eks/aws_auth_config"

  # needed for the local exec
  aws_region = var.aws_region 

  cluster_name = module.eks.cluster_name

  # Map Roles- github open_id connect role arn
  map_roles = [
    {
      rolearn  = "${var.github_oidc_role_arn}"
      username = "github"
      groups   = ["system:masters"]
    }
  ]

  # AWS Local Users permissions over the EKS
  eks_user_access_map = local.map_users

  depends_on = [
    module.eks,
    module.node_groups
  ]
}

module "aws_load_balancer_controller" {
  source        = "../modules/helm/aws-load-balancer-controller"
  
  project_tag        = var.project_tag
  environment        = var.environment

  chart_version        = var.aws_lb_controller_chart_version
  service_account_name = "aws-load-balancer-controller-${var.environment}-service-account"
  release_name         = "aws-load-balancer-controller-${var.environment}"
  namespace            = var.eks_addons_namespace
  
  vpc_id               = module.vpc.vpc_id

  # EKS related variables
  cluster_name         = module.eks.cluster_name
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = module.eks.cluster_oidc_issuer_url

  depends_on = [module.eks, module.node_groups]
}

module "external_dns" {
  source = "../modules/helm/external-dns"

  project_tag        = var.project_tag
  environment        = var.environment

  chart_version        = var.external_dns_chart_version
  service_account_name = "external-dns-${var.environment}-service-account"
  release_name         = "external-dns-${var.environment}"
  namespace            = var.eks_addons_namespace

  # DNS settings
  domain_filter      = var.domain_name
  txt_owner_id       = "externaldns-${var.project_tag}-${var.environment}"
  zone_type          = "public"
  hosted_zone_id     = module.route53.zone_id

  # EKS related variables
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.cluster_oidc_issuer_url
  
  depends_on = [
    module.eks, 
    module.node_groups,
    module.aws_load_balancer_controller
  ]
}

module "cluster_autoscaler" {
  source = "../modules/helm/cluster-autoscaler"

  project_tag        = var.project_tag
  environment        = var.environment

  chart_version        = var.cluster_autoscaler_chart_version
  service_account_name = "cluster-autoscaler-${var.environment}-service-account"
  release_name         = "cluster-autoscaler-${var.environment}"
  namespace            = var.eks_addons_namespace
  
  # EKS related variables
  cluster_name       = module.eks.cluster_name
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.cluster_oidc_issuer_url
  autoscaling_group_arns = local.autoscaling_group_arns

  depends_on = [
    module.eks,
    module.node_groups,
    module.aws_load_balancer_controller.webhook_ready
  ]
}

module "metrics_server" {
  source = "../modules/helm/metrics-server"

  project_tag  = var.project_tag
  environment  = var.environment

  chart_version = var.metrics_server_chart_version
  service_account_name = "metrics-server-${var.environment}-service-account"
  release_name  = "metrics-server-${var.environment}"
  namespace     = var.eks_addons_namespace

  # Resource configuration
  cpu_requests    = "100m"
  memory_requests = "200Mi"
  cpu_limits      = "1000m"
  memory_limits   = "1000Mi"

  depends_on = [
    module.eks,
    module.node_groups,
    module.aws_load_balancer_controller.webhook_ready
  ]
}

module "frontend" {
  source       = "../modules/apps/frontend"

  project_tag        = var.project_tag
  environment        = var.environment

  service_account_name      = var.frontend_service_account_name
  namespace                 = var.frontend_service_namespace

  kms_key_arn               = module.kms.kms_key_arn
  s3_bucket_arn             = module.s3.bucket_arn

  # EKS related variables
  oidc_provider_arn         = module.eks.oidc_provider_arn
  oidc_provider_url         = module.eks.cluster_oidc_issuer_url
  
  depends_on = [
    module.eks,
    module.node_groups,
    module.aws_load_balancer_controller.webhook_ready
  ]
}

# This modules creates an AWS managed secrets, names derived off var.*_aws_secret_key
# The secret holds a json, with key:value pairs
# This gets consumed afterwards by the external secrets operator module
module "secrets_app_envs" {
  source = "../modules/secrets-manager"

  project_tag = var.project_tag
  environment = var.environment
  
  secrets_config_with_passwords = {}
  secret_keys                   = local.secret_keys
  app_secrets_config            = local.app_secrets_config
}

module "argocd_templates" {  
  source = "../modules/gitops/argocd-templates"
  
  project_tag                 = var.project_tag
  argocd_namespace            = var.argocd_namespace
  github_org                  = var.github_org
  github_gitops_repo          = var.github_gitops_repo
  github_application_repo     = var.github_application_repo
  environment                 = var.environment
  app_of_apps_path            = var.argocd_app_of_apps_path
  app_of_apps_target_revision = var.argocd_app_of_apps_target_revision
}

module "gitops_bootstrap" {
  count = (var.bootstrap_mode || var.update_apps) ? 1 : 0
  
  source = "../modules/gitops/bootstrap"
  
  # Pass the raw data to module
  # current_files_data = data.github_repository_file.current_gitops_files
  # gitops_repo_name   = data.github_repository.gitops_repo.name

  # GitHub Configuration
  github_gitops_repo      = var.github_gitops_repo
  github_org              = var.github_org  
  github_application_repo = var.github_application_repo
  github_token            = var.github_token

  # Project Configuration
  project_tag   = var.project_tag
  environment   = var.environment
  
  # ECR Repository URLs
  ecr_frontend_repo_url = module.ecr.ecr_repository_urls["welcome"]
  
  # Frontend Configuration
  frontend_namespace              = var.frontend_service_namespace
  frontend_service_account_name   = var.frontend_service_account_name
  frontend_container_port         = var.frontend_container_port
  frontend_ingress_host           = "${var.frontend_base_domain_name}.${var.subdomain_name}.${var.domain_name}"
  frontend_external_dns_hostname  = "${var.frontend_base_domain_name}.${var.subdomain_name}.${var.domain_name}"
  frontend_argocd_app_name        = var.frontend_argocd_app_name
  frontend_helm_release_name      = var.frontend_helm_release_name
  
  # Shared ALB Configuration
  alb_group_name         = local.alb_group_name
  alb_security_groups    = module.security_groups.joined_security_group_ids
  acm_certificate_arn    = module.acm.this_certificate_arn
  
  # ArgoCD Configuration
  argocd_namespace = var.argocd_namespace
  argocd_project_yaml     = module.argocd_templates.project_yaml
  argocd_app_of_apps_yaml = module.argocd_templates.app_of_apps_yaml
  
  # Control Variables
  bootstrap_mode = var.bootstrap_mode
  update_apps    = var.update_apps
  auto_merge_pr = var.auto_merge_pr
  
  # Branch details for PR creations
  branch_name_prefix  = var.branch_name_prefix
  target_branch       = var.gitops_target_branch
}

# the initial app_of_apps sync has been automated
# this option requires argoCD to be created only AFTER everything else is ready
# we accept that the initial sync might fail (mainly due to missing ecr images, until they are built)
# also, in this module the Project & App_of_apps will created (helm actually manages them both)
#   the bootstrap module creates reference only copies of project/app of apps
          ####### important: App_of_Apps will only be set-up during the helm install
module "argocd" {
  source         = "../modules/helm/argocd"

  project_tag        = var.project_tag
  environment        = var.environment

  chart_version         = var.argocd_chart_version
  service_account_name  = local.argocd_service_account_name
  release_name          = "argocd-${var.environment}"
  namespace             = var.argocd_namespace
  
  # EKS related variables
  oidc_provider_arn     = module.eks.oidc_provider_arn
  oidc_provider_url     = module.eks.cluster_oidc_issuer_url

  # ALB and networking
  domain_name                 = "${var.argocd_base_domain_name}-${var.environment}.${var.subdomain_name}.${var.domain_name}"
  ingress_controller_class    = var.ingress_controller_class
  alb_group_name              = local.alb_group_name
  acm_cert_arn                = module.acm.this_certificate_arn
  argocd_allowed_cidr_blocks  = var.argocd_allowed_cidr_blocks
  alb_security_groups         = module.security_groups.joined_security_group_ids

  # Github SSO
  github_admin_team             = var.github_admin_team
  github_readonly_team          = var.github_readonly_team
  argocd_github_sso_secret_name = local.argocd_github_sso_secret_name
  github_org                    = var.github_org

  # ArgoCD Configuration
  argocd_project_yaml     = module.argocd_templates.project_yaml
  argocd_app_of_apps_yaml = module.argocd_templates.app_of_apps_yaml

  # Secret configuration
  secret_arn = module.secrets_app_envs.app_secrets_arns["${var.argocd_aws_secret_key}"]

  # ================================
  # Resource Configuration - Server
  # ================================
  server_memory_requests = var.argocd_server_memory_requests
  server_cpu_requests    = var.argocd_server_cpu_requests
  server_memory_limits   = var.argocd_server_memory_limits
  server_cpu_limits      = var.argocd_server_cpu_limits
  
  # ================================
  # Resource Configuration - Controller
  # ================================
  controller_memory_requests = var.argocd_controller_memory_requests
  controller_cpu_requests    = var.argocd_controller_cpu_requests
  controller_memory_limits   = var.argocd_controller_memory_limits
  controller_cpu_limits      = var.argocd_controller_cpu_limits
  
  # ================================
  # Resource Configuration - Repo Server
  # ================================
  repo_server_memory_requests = var.argocd_repo_server_memory_requests
  repo_server_cpu_requests    = var.argocd_repo_server_cpu_requests
  repo_server_memory_limits   = var.argocd_repo_server_memory_limits
  repo_server_cpu_limits      = var.argocd_repo_server_cpu_limits
  
  # ================================
  # Resource Configuration - Dex Server
  # ================================
  dex_memory_requests = var.argocd_dex_memory_requests
  dex_cpu_requests    = var.argocd_dex_cpu_requests
  dex_memory_limits   = var.argocd_dex_memory_limits
  dex_cpu_limits      = var.argocd_dex_cpu_limits
  
  # ================================
  # Metrics Configuration
  # ================================
  server_metrics_enabled     = var.argocd_server_metrics_enabled
  controller_metrics_enabled = var.argocd_controller_metrics_enabled
  repo_server_metrics_enabled = var.argocd_repo_server_metrics_enabled
  dex_metrics_enabled        = var.argocd_dex_metrics_enabled

  depends_on = [
    module.eks,
    module.node_groups,
    module.aws_load_balancer_controller.webhook_ready,
    module.acm,
    module.external_dns,
    module.secrets_app_envs
  ]
}

module "save_grafana_password" {
  source = "../modules/secrets-manager"

  project_tag = var.project_tag
  environment = var.environment
  
  secrets_config_with_passwords = local.secrets_config_with_passwords
  app_secrets_config            = {}
}

module "monitoring" {
  count = var.enable_monitoring ? 1 : 0
  
  source = "../modules/helm/kube-prometheus-stack"
  
  project_tag   = var.project_tag
  environment   = var.environment
  
  # Chart configuration
  chart_version = var.kube_prometheus_stack_chart_version
  release_name  = "${var.monitoring_release_name}-${var.environment}"
  namespace     = var.monitoring_namespace
  
  # Domains
  domain_name       = var.domain_name
  grafana_domain    = "${var.grafana_base_domain_name}-${var.environment}.${var.subdomain_name}.${var.domain_name}"
  prometheus_domain = "${var.prometheus_base_domain_name}-${var.environment}.${var.subdomain_name}.${var.domain_name}"
  
  # Ingress configuration
  alb_group_name            = local.alb_group_name
  alb_security_groups       = module.security_groups.joined_security_group_ids
  ingress_controller_class  = var.ingress_controller_class
  acm_certificate_arn       = module.acm.this_certificate_arn
  prometheus_allowed_cidr_blocks = var.prometheus_allowed_cidr_blocks
  grafana_allowed_cidr_blocks    = var.grafana_allowed_cidr_blocks
  
  # Authentication
  grafana_admin_password = random_password.generated_passwords["grafana_admin_password"].result
  
  # Storage configuration
  storage_class = var.monitoring_storage_class
  
  # Prometheus configuration
  prometheus_retention      = var.prometheus_retention
  prometheus_retention_size = var.prometheus_retention_size
  prometheus_storage_size   = var.prometheus_storage_size
  prometheus_cpu_requests   = var.prometheus_cpu_requests
  prometheus_memory_requests = var.prometheus_memory_requests
  prometheus_cpu_limits     = var.prometheus_cpu_limits
  prometheus_memory_limits  = var.prometheus_memory_limits
  
  # Grafana configuration
  grafana_storage_size    = var.grafana_storage_size
  grafana_cpu_requests    = var.grafana_cpu_requests
  grafana_memory_requests = var.grafana_memory_requests
  grafana_cpu_limits      = var.grafana_cpu_limits
  grafana_memory_limits   = var.grafana_memory_limits
  
  # AlertManager configuration
  alertmanager_storage_size    = var.alertmanager_storage_size
  alertmanager_cpu_requests    = var.alertmanager_cpu_requests
  alertmanager_memory_requests = var.alertmanager_memory_requests
  alertmanager_cpu_limits      = var.alertmanager_cpu_limits
  alertmanager_memory_limits   = var.alertmanager_memory_limits
  
  depends_on = [
    module.eks,
    module.node_groups,
    module.aws_load_balancer_controller.webhook_ready,
    module.external_dns,
    module.ebs_csi_driver
  ]
}

module "service_monitors" {
  source = "../modules/monitoring/service-monitors"
  
  project_tag   = var.project_tag
  environment   = var.environment
  
  # Namespaces
  monitoring_namespace         = var.monitoring_namespace
  argocd_namespace            = var.argocd_namespace
  aws_lb_controller_namespace = var.eks_addons_namespace
  
  # Optional features
  enable_dex_metrics = var.enable_dex_metrics
  
  depends_on = [
    module.eks,
    module.monitoring,
    module.argocd,
    module.aws_load_balancer_controller
  ]
}

module "grafana_dashboards" {
  source = "../modules/monitoring/grafana-dashboards"
  
  project_tag   = var.project_tag
  environment   = var.environment
  
  monitoring_namespace       = var.monitoring_namespace
  prometheus_datasource_name = "prometheus"
  
  # Dashboard controls
  enable_aws_lbc_dashboard    = true
  
  depends_on = [
    module.monitoring,
    module.service_monitors
  ]
}

module "external_secrets_operator" {
  source        = "../modules/helm/external-secrets-operator"
  
  project_tag        = var.project_tag
  environment        = var.environment

  #chart_version = "0.9.17"
  chart_version = var.external_secrets_operator_chart_version
  service_account_name = "eso-${var.environment}-service-account"
  release_name       = "external-secrets-${var.environment}"
  namespace          = var.eks_addons_namespace

  # ArgoCD details
  argocd_namespace                = var.argocd_namespace
  argocd_service_account_name     = local.argocd_service_account_name
  #argocd_service_account_role_arn = module.argocd.service_account_role_arn
  argocd_secret_name              = module.secrets_app_envs.app_secrets_names["${var.argocd_aws_secret_key}"]
  argocd_github_sso_secret_name = local.argocd_github_sso_secret_name

  aws_region         = var.aws_region
  
  # Extra values if needed
  set_values = [
  ]
    
  depends_on = [
    module.eks,
    module.node_groups,
    module.aws_auth_config,
    module.argocd,
    module.secrets_app_envs,
    module.aws_load_balancer_controller.webhook_ready
  ]
}

# Application Repo permissions over ECR(s)
module "repo_ecr_access" {
  source = "../modules/github/repo_ecr_access"

  project_tag        = var.project_tag
  environment        = var.environment

  github_org         = var.github_org
  github_repo        = var.github_application_repo
  
  # AWS IAM Identity Provider - created before hand (explained in the variables.tf)
  aws_iam_openid_connect_provider_github_arn = var.aws_iam_openid_connect_provider_github_arn

  ecr_repository_arns = values(module.ecr.ecr_repository_arns)
}

# Creating Repository Secrets and Variables in the Application Repo
module "repo_secrets" {
  source = "../modules/github/repo_secrets"
  
  environment = var.environment

  repository_name = var.github_application_repo

  github_variables = {
    AWS_REGION = var.aws_region
    GITOPS_REPO = "${var.github_org}/${var.github_gitops_repo}"
  }

  # will be Cleaning SHA suffixes from Terraform
  # outputs that sometimes contain --SPLIT-- markers (like ECR urls)
  github_secrets = {
    AWS_ROLE_TO_ASSUME = "${module.repo_ecr_access.github_actions_role_arn}"
    # ECR
    ECR_REPOSITORY_FRONTEND = "${module.ecr.ecr_repository_urls["welcome"]}"
    
    #Github Token (allows App repo to push into gitops repo)
    TOKEN_GITHUB = "${var.github_token}"
  }
}

module "trigger_app_build" {
  count = var.bootstrap_mode ? 1 : 0

  source = "../modules/github/trigger-app-build"
  
  github_token            = var.github_token
  github_org              = var.github_org
  github_application_repo = var.github_application_repo
  environment             = var.environment
  
  depends_on = [
    module.ecr,
    module.repo_secrets,
    module.repo_ecr_access
  ]
}

module "ebs_csi_driver" {
  source = "../modules/helm/ebs-csi-driver"

  project_tag        = var.project_tag
  environment        = var.environment

  chart_version        = "2.35.1"
  service_account_name = "ebs-csi-controller-${var.environment}-sa"
  release_name         = "aws-ebs-csi-driver-${var.environment}"
  namespace            = var.eks_addons_namespace

  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = module.eks.cluster_oidc_issuer_url

  depends_on = [module.eks,module.node_groups]
}

# # ====================================================================
# # EKS LOCKDOWN - Runs after ALL other modules complete
# # ====================================================================
# # IMPORTANT: When adding new modules to main.tf, that use: 
# # kubectl, helm, or kubernetes provider, ADD THEM to the depends_on 
# # list below to ensure EKS lockdown happens after they complete.
# # ====================================================================

# module "eks_lockdown" {
#   source = "../modules/eks/lockdown"
  
#   # EXPLICIT DEPENDENCIES - Add ALL modules here!
#   # This ensures lockdown runs LAST, after all k8s operations complete
#   depends_on = [  
#     # Kubernetes/Helm modules (CRITICAL - these need EKS API access)
#     module.aws_auth_config,
#     module.eks,
#     module.argocd,
#     module.aws_load_balancer_controller,
#     module.cluster_autoscaler,
#     module.external_dns,
#     module.external_secrets_operator,
#     module.monitoring,
#     module.metrics_server,
#     module.ebs_csi_driver,
#     module.service_monitors,
#     module.grafana_dashboards,
#     # Application modules
#     module.frontend,
    
#     # ADD NEW MODULES HERE ↑
#     # Template: module.your_new_module,
#   ]
  
#   # Pass required variables to trigger workflow
#   github_token              = var.github_token
#   github_org                = var.github_org
#   github_repo               = var.github_terraform_repo
#   cluster_security_group_id = module.eks.cluster_security_group_id
#   aws_region                = var.aws_region
#   environment               = var.environment
# }
