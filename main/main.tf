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
  node_security_group_ids = module.security_groups.eks_node_security_group_ids
  
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

module "frontend" {
  source       = "../modules/apps/frontend"

  project_tag        = var.project_tag
  environment        = var.environment

  #vpc_id  = module.vpc.vpc_id

  service_account_name      = var.frontend_service_account_name
  namespace                 = var.frontend_service_namespace

  # EKS related variables
  oidc_provider_arn         = module.eks.oidc_provider_arn
  oidc_provider_url         = module.eks.cluster_oidc_issuer_url
  #node_group_security_groups = module.eks.node_group_security_group_ids
  
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

  project_tag = var.project_tag
  environment = var.environment
  
  #secrets_config_with_passwords = {}
  secret_keys                   = local.secret_keys
  app_secrets_config            = local.app_secrets_config
  
  #depends_on = [module.secrets_rds_password]
}

module "gitops_bootstrap" {
  #count = (var.bootstrap_mode || var.update_apps) ? 1 : 0
  
  source = "../modules/gitops-bootstrap"
  
  # Pass the raw data to module
  current_files_data = data.github_repository_file.current_gitops_files
  gitops_repo_name   = data.github_repository.gitops_repo.name

  # GitHub Configuration
  gitops_repo_owner       = var.github_org
  github_gitops_repo      = var.github_gitops_repo
  github_org              = var.github_org  
  github_application_repo = var.github_application_repo
  github_token            = var.github_token
  
  # Project Configuration
  project_tag   = var.project_tag
  app_name      = var.project_tag
  environment   = var.environment
  aws_region    = var.aws_region
  
  # ECR Repository URLs
  ecr_frontend_repo_url = module.ecr.ecr_repository_urls["frontend"]
  # not needed
  #ecr_backend_repo_url  = module.ecr.ecr_repository_urls["backend"]
  
  # Frontend Configuration
  frontend_namespace              = var.frontend_service_namespace
  frontend_service_account_name   = var.frontend_service_account_name
  frontend_container_port         = var.frontend_container_port
  frontend_ingress_host           = "${var.frontend_base_domain_name}.${var.subdomain_name}.${var.domain_name}"
  frontend_external_dns_hostname  = "${var.frontend_base_domain_name}.${var.subdomain_name}.${var.domain_name}"
  frontend_argocd_app_name        = var.frontend_argocd_app_name
  frontend_helm_release_name      = var.frontend_helm_release_name

  # frontend_external_secret_name   = "frontend-app-secrets"
  # frontend_aws_secret_key         = var.frontend_aws_secret_key
  
  # Backend Configuration  
  # backend_namespace               = var.backend_service_namespace
  # backend_service_account_name    = var.backend_service_account_name
  # backend_container_port          = 3000
  # backend_ingress_host            = "${var.backend_base_domain_name}.${var.subdomain_name}.${var.domain_name}"
  # backend_external_dns_hostname   = "${var.backend_base_domain_name}.${var.subdomain_name}.${var.domain_name}"
  # backend_external_secret_name    = "backend-app-secrets"
  # backend_aws_secret_key          = var.backend_aws_secret_key
  
  # Shared ALB Configuration
  alb_group_name         = local.alb_group_name
  alb_security_groups    = module.security_groups.joined_security_group_ids
  acm_certificate_arn    = module.acm.this_certificate_arn
  
  # ArgoCD Configuration
  argocd_namespace = var.argocd_namespace
  
  # Control Variables
  bootstrap_mode = var.bootstrap_mode
  update_apps    = var.update_apps
  
  # Branch details for PR creations
  branch_name_prefix  = var.branch_name_prefix
  target_branch       = var.gitops_target_branch
  
  depends_on = [
    data.github_repository.gitops_repo,
    data.github_repository_file.current_gitops_files
  ]
}

# the initial app_of_apps sync has been automated
# this option requires argoCD to be created only AFTER everything else is ready
# for example, app repo workflow for build & push 
# including PR merges from both TF & app repo (digest update)
module "argocd" {
  # Create the module only if the variable is true
  count = var.argocd_enabled ? 1 : 0

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

  # ingress / ALB settings
  ingress_controller_class  = var.ingress_controller_class
  alb_group_name            = local.alb_group_name
  
  # Networking
  vpc_id = module.vpc.vpc_id
  argocd_allowed_cidr_blocks    = var.argocd_allowed_cidr_blocks

  # Certificate
  domain_name                   = "${var.argocd_base_domain_name}-${var.environment}.${var.subdomain_name}.${var.domain_name}"
  acm_cert_arn                  = module.acm.this_certificate_arn

  # Security Groups
  alb_security_groups    = module.security_groups.joined_security_group_ids
  #node_group_security_groups    = module.eks.node_group_security_group_ids
  
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
  #frontend_security_group_id    = module.frontend.security_group_id

  secret_arn = module.secrets_app_envs.app_secrets_arns["${var.argocd_aws_secret_key}"]

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
    
  depends_on = [
    module.eks,
    module.aws_auth_config,
    module.argocd,
    module.secrets_app_envs,
    module.aws_load_balancer_controller.webhook_ready
  ]
}

# Application Repo permissions over ECR(s)
module "repo_ecr_access" {
  source = "../modules/repo_ecr_access"

  project_tag        = var.project_tag
  environment        = var.environment

  github_org         = var.github_org
  github_repo        = var.github_application_repo
  # AWS IAM Identity Provider - created before hand (explained in the variables.tf)
  aws_iam_openid_connect_provider_github_arn = var.aws_iam_openid_connect_provider_github_arn

  ecr_repository_arns = [
    module.ecr.ecr_repository_arns["frontend"]
  ]
  # Also an option (generalized but implicit)
  # ecr_repository_arns = values(module.ecr.ecr_repository_arns)
}

# Creating Repository Secrets and Variables in the Application Repo
module "repo_secrets" {
  source = "../modules/repo_secrets"
  
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
    ECR_REPOSITORY_FRONTEND = "${module.ecr.ecr_repository_urls["frontend"]}"
    
    #Github Token (allows App repo to push into gitops repo)
    TOKEN_GITHUB = "${var.github_token}"
  }
}

module "security_groups" {
  source = "../modules/security_groups"

  project_tag        = var.project_tag
  environment        = var.environment

  vpc_id = module.vpc.vpc_id
  #node_group_security_groups = module.eks.node_group_security_group_ids
  argocd_allowed_cidr_blocks    = var.argocd_allowed_cidr_blocks

  # Node group configuration
  node_groups = var.eks_node_groups
}

# ── CLUSTER to NODES (Egress from Cluster Security Group) ──

resource "aws_vpc_security_group_egress_rule" "cluster_to_node_kubelet" {
  for_each = var.node_groups

  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.nodes[each.key].id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  description                  = "REQUIRED: Cluster control plane to kubelet API on ${each.key} nodes"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "eks-essential"
    Rule    = "cluster-to-kubelet"
  }
}

resource "aws_vpc_security_group_egress_rule" "cluster_to_node_ephemeral" {
  for_each = var.node_groups

  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.nodes[each.key].id
  from_port                    = 1025
  to_port                      = 65535
  ip_protocol                  = "tcp"
  description                  = "REQUIRED: Cluster control plane to ephemeral ports on ${each.key} nodes (includes pod-to-pod via CNI)"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "eks-essential"
    Rule    = "cluster-to-ephemeral"
    Note    = "Covers kubelet(10250) and HTTPS(443) but kept separate for documentation"
  }
}

resource "aws_vpc_security_group_egress_rule" "cluster_to_node_https" {
  for_each = var.node_groups

  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.nodes[each.key].id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "DOCUMENTATION: Cluster control plane to HTTPS on ${each.key} nodes (covered by ephemeral rule but explicit for clarity)"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "documentation"
    Rule    = "cluster-to-https"
    Note    = "Redundant with ephemeral rule - kept for explicit documentation"
  }
}

# ── NODES to CLUSTER (Egress from Node Security Groups) ──

resource "aws_vpc_security_group_egress_rule" "node_to_cluster_api" {
  for_each = var.node_groups

  security_group_id            = aws_security_group.nodes[each.key].id
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "REQUIRED: ${each.key} nodes to cluster API server (authentication, API calls)"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "eks-essential"
    Rule    = "node-to-api"
  }
}

# ── CLUSTER ← NODES (Ingress to Cluster Security Group) ──

resource "aws_vpc_security_group_ingress_rule" "cluster_allow_node_api" {
  for_each = var.node_groups

  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.nodes[each.key].id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "REQUIRED: Allow ${each.key} nodes to cluster API server access"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "eks-essential"
    Rule    = "allow-node-to-api"
  }
}

# ── NODES ← CLUSTER (Ingress to Node Security Groups) ──

resource "aws_vpc_security_group_ingress_rule" "node_allow_cluster_kubelet" {
  for_each = var.node_groups

  security_group_id            = aws_security_group.nodes[each.key].id
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  description                  = "REQUIRED: Allow cluster control plane to kubelet on ${each.key} nodes"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "eks-essential"
    Rule    = "allow-cluster-to-kubelet"
  }
}

resource "aws_vpc_security_group_ingress_rule" "node_allow_cluster_ephemeral" {
  for_each = var.node_groups

  security_group_id            = aws_security_group.nodes[each.key].id
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port                    = 1025
  to_port                      = 65535
  ip_protocol                  = "tcp"
  description                  = "REQUIRED: Allow cluster control plane to ephemeral ports on ${each.key} nodes"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "eks-essential"
    Rule    = "allow-cluster-to-ephemeral"
  }
}

resource "aws_vpc_security_group_ingress_rule" "node_allow_cluster_https" {
  for_each = var.node_groups

  security_group_id            = aws_security_group.nodes[each.key].id
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "DOCUMENTATION: Allow cluster control plane to HTTPS on ${each.key} nodes (covered by ephemeral but explicit)"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "documentation"
    Rule    = "allow-cluster-to-https"
    Note    = "Redundant with ephemeral rule - kept for explicit documentation"
  }
}

# ================================
# SECTION 2: EXTERNAL ACCESS
# Purpose: Allow access from outside the VPC to cluster services
# ================================

resource "aws_vpc_security_group_ingress_rule" "eks_api_from_cidrs" {
  for_each = toset(var.eks_api_allowed_cidr_blocks)

  security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
  description       = "EXTERNAL: Allow kubectl/API access from ${each.value} (GitHub Actions, admin IPs)"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "external-access"
    Rule    = "api-from-cidr"
    Source  = each.value
  }
}

# ================================
# SECTION 3: INTRA-CLUSTER COMMUNICATION
# Purpose: Enable pod-to-pod communication within and across node groups
# This is what enables Kubernetes networking to function
# ================================

# ── SAME NODE GROUP COMMUNICATION ──

resource "aws_vpc_security_group_ingress_rule" "node_to_node_same_group" {
  for_each = var.node_groups

  security_group_id            = aws_security_group.nodes[each.key].id
  referenced_security_group_id = aws_security_group.nodes[each.key].id
  ip_protocol                  = "-1"  # All protocols
  description                  = "INTRA-GROUP: Allow all communication between nodes within ${each.key} group (pod-to-pod, service discovery)"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "kubernetes-networking"
    Rule    = "same-group-ingress"
    Scope   = each.key
  }
}

resource "aws_vpc_security_group_egress_rule" "node_to_node_same_group" {
  for_each = var.node_groups

  security_group_id            = aws_security_group.nodes[each.key].id
  referenced_security_group_id = aws_security_group.nodes[each.key].id
  ip_protocol                  = "-1"  # All protocols
  description                  = "INTRA-GROUP: Allow all communication from nodes within ${each.key} group"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "kubernetes-networking"
    Rule    = "same-group-egress"
    Scope   = each.key
  }
}

# ── CROSS NODE GROUP COMMUNICATION ──

resource "aws_vpc_security_group_ingress_rule" "cross_nodegroup_communication" {
  for_each = {
    for pair in local.node_group_pairs : "${pair.source}-to-${pair.target}" => pair
  }

  security_group_id            = aws_security_group.nodes[each.value.target].id
  referenced_security_group_id = aws_security_group.nodes[each.value.source].id
  ip_protocol                  = "-1"  # All protocols
  description                  = "CROSS-GROUP: Allow all communication from ${each.value.source} nodes to ${each.value.target} nodes (enables pod scheduling flexibility)"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "kubernetes-networking"
    Rule    = "cross-group-ingress"
    Source  = each.value.source
    Target  = each.value.target
  }
}

resource "aws_vpc_security_group_egress_rule" "cross_nodegroup_communication" {
  for_each = {
    for pair in local.node_group_pairs : "${pair.source}-to-${pair.target}" => pair
  }

  security_group_id            = aws_security_group.nodes[each.value.source].id
  referenced_security_group_id = aws_security_group.nodes[each.value.target].id
  ip_protocol                  = "-1"  # All protocols
  description                  = "CROSS-GROUP: Allow all communication from ${each.value.source} nodes to ${each.value.target} nodes"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "kubernetes-networking"
    Rule    = "cross-group-egress"
    Source  = each.value.source
    Target  = each.value.target
  }
}

# ================================
# SECTION 4: INTERNET ACCESS
# Purpose: Enable nodes to reach external services (AWS APIs, package repos, registries)
# REDUNDANCY NOTE: The 'all_outbound' rule makes most specific rules redundant,
# but we keep specific rules for documentation and future granular control
# ================================

# ── OPERATIONAL RULE: Broad Internet Access ──

resource "aws_vpc_security_group_egress_rule" "nodes_all_outbound" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "OPERATIONAL: Allow all outbound traffic from ${each.key} nodes (simplifies troubleshooting, covers all AWS APIs)"
  
  ip_protocol = "-1"  # All protocols
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name    = "${var.project_tag}-${var.environment}-${each.key}-all-outbound"
    Purpose = "operational-simplicity"
    Rule    = "all-outbound"
    Note    = "Makes specific rules below redundant but kept for documentation"
  }
}

# -- DOCUMENTATION RULES: Specific Services --
# These rules are COVERED by the all_outbound rule above but kept for:
# 1. Explicit documentation of what services nodes need
# 2. Future ability to remove all_outbound and use granular rules
# 3. Security audit clarity

resource "aws_vpc_security_group_egress_rule" "nodes_dns_udp" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "DOCUMENTATION: DNS resolution (UDP) from ${each.key} nodes to internet (covered by all_outbound)"
  
  ip_protocol = "udp"
  from_port   = 53
  to_port     = 53
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "documentation"
    Rule    = "dns-udp"
    Note    = "Redundant with all_outbound - kept for explicit documentation"
  }
}

resource "aws_vpc_security_group_egress_rule" "nodes_dns_tcp" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "DOCUMENTATION: DNS resolution (TCP) from ${each.key} nodes to internet (large queries, covered by all_outbound)"
  
  ip_protocol = "tcp"
  from_port   = 53
  to_port     = 53
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "documentation"
    Rule    = "dns-tcp"
    Note    = "Redundant with all_outbound - kept for explicit documentation"
  }
}

resource "aws_vpc_security_group_egress_rule" "nodes_https_outbound" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "DOCUMENTATION: HTTPS from ${each.key} nodes to AWS APIs, registries (covered by all_outbound)"
  
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "documentation"
    Rule    = "https-outbound"
    Note    = "Redundant with all_outbound - kept for explicit documentation"
  }
}

resource "aws_vpc_security_group_egress_rule" "nodes_http_outbound" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "DOCUMENTATION: HTTP from ${each.key} nodes to package repos, updates (covered by all_outbound)"
  
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "documentation"
    Rule    = "http-outbound"
    Note    = "Redundant with all_outbound - kept for explicit documentation"
  }
}

resource "aws_vpc_security_group_egress_rule" "nodes_ntp" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "DOCUMENTATION: NTP from ${each.key} nodes to time servers (covered by all_outbound)"
  
  ip_protocol = "udp"
  from_port   = 123
  to_port     = 123
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Purpose = "documentation"
    Rule    = "ntp-outbound"
    Note    = "Redundant with all_outbound - kept for explicit documentation"
  }
}

resource "aws_vpc_security_group_egress_rule" "nodes_ephemeral_tcp" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "DOCUMENTATION: Ephemeral TCP ports from ${each.key} nodes to outbound connections (covered by all_outbound)"
  
  ip_protocol = "tcp"
  from_port   = 1024
  to_port     = 65535
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name    = "${var.project_tag}-${var.environment}-${each.key}-ephemeral-tcp"
    Purpose = "documentation"
    Rule    = "ephemeral-tcp"
    Note    = "Redundant with all_outbound - kept for explicit documentation"
  }
}

resource "aws_vpc_security_group_egress_rule" "nodes_custom_ports" {
  for_each = var.node_groups

  security_group_id = aws_security_group.nodes[each.key].id
  description       = "DOCUMENTATION: Custom app ports from ${each.key} nodes to external services (covered by all_outbound)"
  
  ip_protocol = "tcp"
  from_port   = 8000
  to_port     = 8999
  cidr_ipv4   = "0.0.0.0/0"
  
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name    = "${var.project_tag}-${var.environment}-${each.key}-custom-ports"
    Purpose = "documentation"
    Rule    = "custom-ports"
    Note    = "Redundant with all_outbound - kept for explicit documentation"
  }
}

# ================================
# SECURITY GROUP RULES SUMMARY
# ================================
# ESSENTIAL RULES (Required for EKS to function):
#   - cluster_to_node_kubelet / node_allow_cluster_kubelet
#   - cluster_to_node_ephemeral / node_allow_cluster_ephemeral  
#   - node_to_cluster_api / cluster_allow_node_api
#   - nodes_all_outbound (for AWS API access)
#   - cross_nodegroup_communication (for multi-nodegroup pod scheduling)
#
# DOCUMENTATION RULES (Redundant but kept for clarity):
#   - cluster_to_node_https / node_allow_cluster_https (covered by ephemeral)
#   - nodes_dns_* / nodes_https_outbound / nodes_http_outbound (covered by all_outbound)
#   - nodes_ephemeral_tcp / nodes_custom_ports (covered by all_outbound)
#
# EXTERNAL ACCESS:
#   - eks_api_from_cidrs (admin/CI access to cluster API)
#
# ARCHITECTURE DECISION:
# We use a layered approach with both broad rules (operational simplicity) 
# and specific rules (documentation/future granular control). This provides:
# 1. Operational reliability (broad rules ensure everything works)
# 2. Security documentation (specific rules show exactly what's needed)  
# 3. Future flexibility (can remove broad rules and use specific ones)
# ================================

