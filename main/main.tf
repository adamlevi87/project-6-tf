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

module "s3_app_data" {
  source = "../modules/s3"

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
  subdomain_name = var.subdomain_name

  # cloudfront_domain_name = module.cloudfront.cloudfront_domain_name
  # json_view_base_domain_name = local.json_view_base_domain_name

  # alb_dns_name = 1
  # alb_zone_id = 1
}

module "acm" {
  source           = "../modules/acm"

  project_tag      = var.project_tag
  environment      = var.environment

  cert_domain_name  = "*.${var.subdomain_name}.${var.domain_name}"
  route53_zone_id  = module.route53.zone_id
}

module "eks" {
  source = "../modules/eks"

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






