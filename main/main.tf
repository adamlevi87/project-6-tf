# main/main.tf

module "vpc" {
    source = "../modules/vpc"

    aws_provider_version = var.aws_provider_version

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

  aws_provider_version = var.aws_provider_version

  project_tag = var.project_tag
  environment = var.environment

  account_id  = local.account_id

  # KMS configuration
  deletion_window_in_days = var.environment == "prod" ? 30 : 7
  enable_key_rotation     = true
}

module "s3" {
  source = "../modules/s3"

  aws_provider_version = var.aws_provider_version
  
  project_tag   = var.project_tag
  environment   = var.environment

  # KMS encryption
  kms_key_arn = module.kms.kms_key_arn
  
  # Lifecycle configuration
  enable_lifecycle_policy = true
  data_retention_days     = var.environment == "prod" ? 0 : 365  # Keep prod data forever, dev/staging for 1 year

  # Allow force destroy for non-prod environments
  force_destroy = var.environment != "prod"

  depends_on = [module.kms]
}

module "ecr" {
  source = "../modules/ecr"

  aws_provider_version = var.aws_provider_version

  project_tag  = var.project_tag
  environment = var.environment
  
  ecr_repository_name = var.ecr_repository_name
  ecr_repositories_applications = var.ecr_repositories_applications
}

module "route53" {
  source       = "../modules/route53"

  aws_provider_version = var.aws_provider_version

  project_tag  = var.project_tag
  environment  = var.environment
  
  domain_name    = var.domain_name
  subdomain_name = var.subdomain_name

  # cloudfront_domain_name = module.cloudfront.cloudfront_domain_name
  # json_view_base_domain_name = local.json_view_base_domain_name

  # alb_dns_name = 1
  # alb_zone_id = 1
}

module "acm" {
  source           = "../modules/acm"

  aws_provider_version = var.aws_provider_version

  project_tag      = var.project_tag
  environment      = var.environment

  cert_domain_name  = "*.${var.subdomain_name}.${var.domain_name}"
  route53_zone_id  = module.route53.zone_id
}

module "eks" {
  source = "../modules/eks"

  aws_provider_version = var.aws_provider_version
  
  project_tag = var.project_tag
  environment = var.environment

  # Cluster configuration
  cluster_name        = "${var.project_tag}-${var.environment}-cluster"
  kubernetes_version  = var.eks_kubernetes_version
  
  # Networking (from VPC module)
  private_subnet_ids   = module.vpc.private_subnet_ids
  eks_api_allowed_cidr_blocks  = var.eks_api_allowed_cidr_blocks
  vpc_id = module.vpc.vpc_id
  
  # Node group configuration
  node_groups = var.eks_node_groups
  
  # Logging
  cluster_enabled_log_types = var.cluster_enabled_log_types
  cluster_log_retention_days = var.eks_log_retention_days

  # ECR for nodegroup permissions
  ecr_repository_arns = module.ecr.ecr_repository_arns
}

module "aws_auth_config" {
  source = "../modules/aws_auth_config"

  aws_provider_version        = var.aws_provider_version
  kubernetes_provider_version = var.kubernetes_provider_version

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

  depends_on = [module.eks]
}

module "aws_load_balancer_controller" {
  source        = "../modules/helm/aws-load-balancer-controller"
  
  aws_provider_version        = var.aws_provider_version
  kubernetes_provider_version = var.kubernetes_provider_version
  helm_provider_version       = var.helm_provider_version

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

  depends_on = [module.eks]
}

module "external_dns" {
  source = "../modules/helm/external-dns"

  aws_provider_version        = var.aws_provider_version
  kubernetes_provider_version = var.kubernetes_provider_version
  helm_provider_version       = var.helm_provider_version

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
  
  depends_on = [module.eks, module.aws_load_balancer_controller.webhook_ready]
}

module "cluster_autoscaler" {
  source = "../modules/helm/cluster-autoscaler"

  aws_provider_version        = var.aws_provider_version
  kubernetes_provider_version = var.kubernetes_provider_version
  helm_provider_version       = var.helm_provider_version

  project_tag        = var.project_tag
  environment        = var.environment

  service_account_name = "cluster-autoscaler-${var.environment}-service-account"
  release_name         = "cluster-autoscaler"
  namespace            = var.eks_addons_namespace
  
  # EKS related variables
  cluster_name       = module.eks.cluster_name
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.cluster_oidc_issuer_url
  autoscaling_group_arns = values(module.eks.autoscaling_group_arns)

  depends_on = [module.eks, module.aws_load_balancer_controller.webhook_ready]
}

module "metrics_server" {
  source = "../modules/helm/metrics-server"

  kubernetes_provider_version = var.kubernetes_provider_version
  helm_provider_version       = var.helm_provider_version

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

  depends_on = [module.eks, module.aws_load_balancer_controller.webhook_ready]
}

module "frontend" {
  source       = "../modules/apps/frontend"

  aws_provider_version        = var.aws_provider_version
  kubernetes_provider_version = var.kubernetes_provider_version

  project_tag        = var.project_tag
  environment        = var.environment

  vpc_id  = module.vpc.vpc_id

  service_account_name      = var.frontend_service_account_name
  namespace                 = var.frontend_service_namespace

  # EKS related variables
  oidc_provider_arn         = module.eks.oidc_provider_arn
  oidc_provider_url         = module.eks.cluster_oidc_issuer_url
  node_group_security_groups = module.eks.node_group_security_group_ids
  
  depends_on = [
    module.eks, 
    module.aws_load_balancer_controller.webhook_ready
  ]
}

# This modules creates an AWS managed secrets, names derived off var.*_aws_secret_key
# The secret holds a json, with key:value pairs
# This gets consumed afterwards by the external secrets operator module
module "secrets_app_envs" {
  source = "../modules/secrets-manager"

  aws_provider_version  = var.aws_provider_version

  project_tag = var.project_tag
  environment = var.environment
  
  #secrets_config_with_passwords = {}
  secret_keys                   = local.secret_keys
  app_secrets_config            = local.app_secrets_config
  
  #depends_on = [module.secrets_rds_password]
}

module "argocd" {
  # Create the module only if the variable is true
  count = var.argocd_enabled ? 1 : 0

  source         = "../modules/helm/argocd"

  aws_provider_version        = var.aws_provider_version
  kubernetes_provider_version = var.kubernetes_provider_version
  helm_provider_version       = var.helm_provider_version

  project_tag        = var.project_tag
  environment        = var.environment

  chart_version         = var.argocd_chart_version
  service_account_name  = local.argocd_service_account_name
  release_name          = "argocd-${var.environment}"
  namespace             = var.argocd_namespace
  
  # EKS related variables
  oidc_provider_arn     = module.eks.oidc_provider_arn
  oidc_provider_url     = module.eks.cluster_oidc_issuer_url

  # ingress / ALB settings
  ingress_controller_class  = var.ingress_controller_class
  alb_group_name            = "${var.project_tag}-${var.environment}-alb-shared-group"
  
  # Networking
  vpc_id = module.vpc.vpc_id
  argocd_allowed_cidr_blocks    = var.argocd_allowed_cidr_blocks

  # Certificate
  domain_name                   = "${var.argocd_base_domain_name}-${var.environment}.${var.subdomain_name}.${var.domain_name}"
  acm_cert_arn                  = module.acm.this_certificate_arn

  # Security Groups
  node_group_security_groups    = module.eks.node_group_security_group_ids
  
  # Github Settings
  github_org                    = var.github_org
  github_application_repo       = var.github_application_repo
  github_gitops_repo            = var.github_gitops_repo
 
  # ArgoCD Setup
  app_of_apps_path              = var.argocd_app_of_apps_path
  app_of_apps_target_revision   = var.argocd_app_of_apps_target_revision
  
  # Github SSO
  github_admin_team             = var.github_admin_team
  github_readonly_team          = var.github_readonly_team
  argocd_github_sso_secret_name = local.argocd_github_sso_secret_name

  # Security groups for alb creation (via an ingress resource [managed by AWS LBC])
  frontend_security_group_id    = module.frontend.security_group_id

  secret_arn = module.secrets_app_envs.app_secrets_arns["${var.argocd_aws_secret_key}"]

  # Deletion protection after a creation
  lifecycle {
    ignore_changes = [count]  
  }

  depends_on = [
    module.eks,
    module.aws_load_balancer_controller.webhook_ready,
    module.acm
  ]
}

module "external_secrets_operator" {
  # Create the module only if the variable is true
  count = var.argocd_enabled ? 1 : 0

  source        = "../modules/helm/external-secrets-operator"
  
  kubernetes_provider_version = var.kubernetes_provider_version
  helm_provider_version       = var.helm_provider_version

  project_tag        = var.project_tag
  environment        = var.environment

  #chart_version = "0.9.17"
  chart_version = var.external_secrets_operator_chart_version
  service_account_name = "eso-${var.environment}-service-account"
  release_name       = "external-secrets-${var.environment}"
  namespace          = var.eks_addons_namespace

  # EKS related variables
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.cluster_oidc_issuer_url

  # ArgoCD details
  argocd_namespace                = var.argocd_namespace
  argocd_service_account_name     = local.argocd_service_account_name
  argocd_service_account_role_arn = module.argocd.service_account_role_arn
  argocd_secret_name              = module.secrets_app_envs.app_secrets_names["${var.argocd_aws_secret_key}"]
  argocd_github_sso_secret_name = local.argocd_github_sso_secret_name

  aws_region         = var.aws_region
  
  # Extra values if needed
  set_values = [
  ]
  
  # Deletion protection after a creation
  lifecycle {
    ignore_changes = [count]  
  }
  
  depends_on = [
    module.eks,
    module.aws_auth_config,
    module.argocd,
    module.secrets_app_envs,
    module.aws_load_balancer_controller.webhook_ready
  ]
}





