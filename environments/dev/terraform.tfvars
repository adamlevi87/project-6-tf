# environments/dev/terraform.tfvars

# ================================
# General Configurations
# ================================
# AWS Region
aws_region = "us-east-1"

# Project configuration
environment = "dev"
project_tag = "project-6"

# ================================
# VPC Configurations
# ================================
# Network configuration
vpc_cidr_block = "10.0.0.0/16"
nat_mode = "single"  # Options: "single", "real", ("endpoints" - WIP)

# Primary infrastructure (always exists - houses the primary NAT)
primary_availability_zones = 1  # Always keep 1 AZ for primary NAT gateway

# Additional infrastructure (optional in single mode, required in real mode)
additional_availability_zones = 1  # Can be reduced in single mode without affecting primary NAT

# ================================
# S3 Configurations
# ================================
enable_lifecycle_policy = true
s3_policy_deny_rule_name = "DenyAllExceptions"
# ================================
# ECR Configurations
# ================================
ecr_repository_name = "project-6"
ecr_repositories_applications = ["welcome"]

# ================================
# ROUTE53 Configurations (domains,subdomains)
# ================================
domain_name = "projects-devops.cfd"
subdomain_name = "project-6"

# ================================
# EKS Cluster Configurations
# ================================
eks_kubernetes_version = "1.33"

# Whitelist your host + temporary - for github - all IPs - EKS api access
# this is mainly for Github runners until we move onto a better method- (instance in the VPC)
# github workflow that runs the TF apply uses kubernetes/helm modules which requires white-listing the runners
eks_api_allowed_cidr_blocks    = ["85.64.231.47/32","0.0.0.0/0"]

# EKS Node Groups Configuration - Multi-NodeGroup Setup
eks_node_groups = {
  critical = {
    instance_type     = "t3.small"
    ami_id           = "ami-03943441037953e69"
    desired_capacity = 1
    max_capacity     = 5
    min_capacity     = 1
    labels = {
      nodegroup-type = "critical"
      instance-size  = "small"
      workload-type  = "system"
    }
  }
}

# List of cluster log types to enable. Available options: api, audit, authenticator, controllerManager, scheduler
# to enable use cluster_enabled_log_types = ["api", "audit", "controllerManager", "scheduler"]
cluster_enabled_log_types = ["api", "audit", "controllerManager", "scheduler"] # For dev - this might not be needed

# EKS Logging Configuration (minimal retention for cost)
eks_log_retention_days = 7  # 1 week retention for dev environment

# EKS addons
eks_addons_namespace = "kube-system"
# latest versions of each chart for 09/2025
aws_lb_controller_chart_version     = "1.13.4"
external_dns_chart_version          = "1.19.0"
cluster_autoscaler_chart_version    = "9.50.1"
metrics_server_chart_version        = "3.13.0"
external_secrets_operator_chart_version = "0.9.17"
#external_secrets_operator_chart_version = "0.19.2"

eks_user_access_map = {
  adam_local = {
    username = "adam.local"
    groups   = ["system:masters"]
  }
  adam_login = {
    username = "adam.login"
    groups   = ["system:masters"]
  }
}

# frontend service details
frontend_service_namespace    = "frontend"
frontend_service_account_name = "frontend-sa"

# Github Details
github_org = "adamlevi87"
github_application_repo = "project-6-app"
github_gitops_repo  = "project-6-gitops"
github_terraform_repo  = "project-6-tf"
github_admin_team = "devops"
github_readonly_team = "developers"

# ArgoCD
argocd_chart_version                = "8.3.6"
argocd_namespace                    = "argocd"
argocd_allowed_cidr_blocks          = ["85.65.167.191/32"]
argocd_base_domain_name             = "argocd"
argocd_app_of_apps_path             = "apps"
argocd_app_of_apps_target_revision  = "main"
argocd_aws_secret_key               = "argocd-credentials"

# ingress controller class
ingress_controller_class = "alb"

# Gitops related settings
update_apps = false
bootstrap_mode = false
auto_merge_pr = false

frontend_container_port = 80
frontend_base_domain_name = "frontend-app"
branch_name_prefix  = "terraform-updates"
frontend_argocd_app_name = "frontend"
frontend_helm_release_name = "frontend"
# From which branch to create a new branch and where to merge back to
# when creating initial yamls in the gitops repo
gitops_target_branch = "main"





############################# commented area



# Gitops related settings





# Frontend and Backend base domain names

# backend_base_domain_name = "backend-app"

# cloudfront_allowed_cidr_blocks = ["85.64.231.47/32"]

# ALB Configuration
#alb_deletion_protection = false  # Allow easy deletion in dev environment

# backend service details
# backend_service_namespace    = "backend"
# backend_service_account_name = "backend-sa"

# Apps (frontend) AWS secret names
# later be used to pull from using ESO
#frontend_aws_secret_key = "frontend-envs"
# backend_aws_secret_key = "backend-envs"




# github_admin_team = "Project-5/devops"
# github_readonly_team = "Project-5/developers"











# # Kyverno Configuration
# kyverno_release_name = "kyverno"
# kyverno_namespace = "kyverno"

# # Cloudfront base url for json viewing (lambda s3 write result)
# json_view_base_domain_name = "json-view"



# container_port = 3000
# task_cpu = 256
# task_memory = 512
# ecs_log_stream_prefix = "ecs"
# ecs_network_mode = "awsvpc"
# ecs_protocol = "tcp"
# ecs_requires_compatibilities = "FARGATE"

# container_name = "chatbot-ui-gpt4-playground"


# allow_destroy_hosted_zone = "true"


# # RDS Configuration
# rds_postgres_version    = "16.9"
# rds_instance_class      = "db.t3.micro"        # Smallest/cheapest option
# rds_database_name       = "myapp_db"           # Match your local postgres
# rds_database_username   = "myapp"              # Match your local postgres
# rds_database_port       = 5432
# # this table name gets create on app initialization (backend)
# rds_postgres_table_name = "messages"

# # Storage (minimal cost)
# rds_allocated_storage     = 20      # AWS minimum for PostgreSQL
# rds_max_allocated_storage = 20     # Allow some autoscaling growth
# rds_storage_type          = "gp2"   # Cheapest storage option
# rds_storage_encrypted         = false

# # Multi-AZ and High Availability (NEW)
# rds_multi_az_enabled = false            # Single AZ for free tier (Multi-AZ costs extra)

# # Backup and maintenance (minimal)
# rds_backup_retention_period = 1                    # 1 day minimum for dev
# rds_backup_window          = "03:00-04:00"         # Low traffic time UTC
# rds_maintenance_window     = "sun:04:00-sun:05:00" # Sunday early morning UTC

# # Protection and snapshot settings
# rds_deletion_protection = false  # Allow easy deletion for dev environment
# # skip_final_snapshot options:
# # true  = No final snapshot when destroying (faster, no storage costs)
# # false = Create final snapshot when destroying (data protection, costs money to store)
# rds_skip_final_snapshot = true   # No final snapshot for dev environment

# # Monitoring (minimal to save costs)
# rds_enable_performance_insights = false  # Disable to save money
# rds_monitoring_interval         = 0      # 0 = disabled, saves costs

# # Additional settings for flexibility (NEW)
# rds_copy_tags_to_snapshot = false            # No snapshots in dev anyway