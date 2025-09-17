# terraform-main/environments/dev/terraform.tfvars

# ================================
# General Configurations
# ================================
# AWS Region
aws_region = "us-east-1"

# Project configuration
environment = "dev"
project_tag = "project-6"
initialize_run = false
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
s3_allowed_principals = [
  "role/project-6-dev-initial-role-for-tf",
  "user/adam.local", 
  "user/adam.login"
]
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
eks_api_allowed_cidr_blocks    = ["85.65.159.200/32"]
endpoint_public_access = false

# EKS Node Groups Configuration - Multi-NodeGroup Setup
eks_node_groups = {
  critical = {
    instance_type     = "t3.small"
    ami_id           = "ami-03943441037953e69"
    desired_capacity = 3
    max_capacity     = 6
    min_capacity     = 2
    labels = {
      nodegroup-type = "critical"
      instance-size  = "small"
      workload-type  = "system"
    }
  }
}

# List of cluster log types to enable. Available options: api, audit, authenticator, controllerManager, scheduler
# to enable use cluster_enabled_log_types = ["api", "audit", "controllerManager", "scheduler"]
cluster_enabled_log_types = [] # For dev - this might not be needed

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
# Groups for SSO permissions (Github SSO for ArgoCD)
github_admin_team = "devops"
github_readonly_team = "developers"

# ================================
# ArgoCD Configuration
# ================================
argocd_chart_version                = "8.3.6"
argocd_namespace                    = "argocd"
argocd_allowed_cidr_blocks          = ["85.65.159.200/32"]
argocd_base_domain_name             = "argocd"
argocd_app_of_apps_path             = "apps"
argocd_app_of_apps_target_revision  = "main"
argocd_aws_secret_key               = "argocd-credentials"

# ================================
# ArgoCD Server Resources
# ================================
argocd_server_memory_requests = "256Mi"
argocd_server_cpu_requests    = "100m"
argocd_server_memory_limits   = "512Mi"
argocd_server_cpu_limits      = "500m"

# ================================
# ArgoCD Application Controller Resources
# ================================
argocd_controller_memory_requests = "1Gi"
argocd_controller_cpu_requests    = "250m"
argocd_controller_memory_limits   = "2Gi"
argocd_controller_cpu_limits      = "1000m"

# ================================
# ArgoCD Repo Server Resources
# ================================
argocd_repo_server_memory_requests = "256Mi"
argocd_repo_server_cpu_requests    = "100m"
argocd_repo_server_memory_limits   = "512Mi"
argocd_repo_server_cpu_limits      = "500m"

# ================================
# ArgoCD Dex Server Resources
# ================================
argocd_dex_memory_requests = "64Mi"
argocd_dex_cpu_requests    = "50m"
argocd_dex_memory_limits   = "128Mi"
argocd_dex_cpu_limits      = "100m"

# ================================
# ArgoCD Metrics Configuration
# ================================
argocd_server_metrics_enabled     = true
argocd_controller_metrics_enabled = true
argocd_repo_server_metrics_enabled = true
argocd_dex_metrics_enabled        = true  # Usually not needed

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

# ================================
# Monitoring Configurations  
# ================================
enable_monitoring = true
monitoring_namespace = "monitoring"
monitoring_release_name = "kube-prometheus-stack"
kube_prometheus_stack_chart_version = "77.6.2"
grafana_base_domain_name = "grafana"
prometheus_base_domain_name = "prometheus"
prometheus_allowed_cidr_blocks = ["85.65.159.200/32"]  # Your IP
grafana_allowed_cidr_blocks    = ["85.65.159.200/32"]
enable_dex_metrics = true
grafana_admin_password = "admin123"
#  = "admin123"  # Change this!
# Configuration for secrets
secrets_config = {
    #dont change map names
    grafana_admin_password = {
        description        = "Admin Password for Grafana"
        generate_password  = true
        password_length    = 16
        password_special   = true
        password_override_special = "!#$%&*()-_=+[]{}|;:,.<>?"
        #secret_value = "example"
    }
    # Future secrets go here
}


# Storage configuration
monitoring_storage_class = "gp2"

# Prometheus configuration
prometheus_retention = "15d"
prometheus_retention_size = "10GB"
prometheus_storage_size = "20Gi"
prometheus_cpu_requests    = "100m"
prometheus_memory_requests = "256Mi" 
prometheus_cpu_limits     = "500m"
prometheus_memory_limits  = "512Mi"

# Grafana configuration
grafana_storage_size = "10Gi"
grafana_cpu_requests    = "50m"
grafana_memory_requests = "128Mi"
grafana_cpu_limits     = "200m" 
grafana_memory_limits   = "256Mi"

# AlertManager configuration
alertmanager_storage_size = "5Gi"
alertmanager_cpu_requests    = "25m"
alertmanager_memory_requests = "64Mi"
alertmanager_cpu_limits     = "100m"
alertmanager_memory_limits   = "128Mi"


############################# commented area