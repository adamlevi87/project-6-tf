# terraform-main/main/locals.tf

data "aws_availability_zones" "available" {
    state = "available"
}

data "aws_caller_identity" "current" {}

locals {
    # Calculate total AZs needed
    total_azs = var.primary_availability_zones + var.additional_availability_zones
    
    # Get all available AZs
    # from [0] to [total_azs (not included, meaning -1)]
    # a list of all avaiability zones starting from the first ([0]) till the # of total azs - [3] not including [3]
    # meaning a list of [0] [1] [2] - would be 3 AZs
    all_availability_zones = slice(data.aws_availability_zones.available.names, 0, local.total_azs)
    
    # Separate primary and additional AZs
    # [0] to [primary_availability_zones  - normally equals 1] so it will return a single AZ name
    primary_azs = slice(local.all_availability_zones, 0, var.primary_availability_zones)
    # going over the list again, slicing it from [1] to [total azs]  which will result in 2 AZ names
    additional_azs = slice(local.all_availability_zones, var.primary_availability_zones, local.total_azs)
    
    # Calculate subnet pairs for all AZs
    # Creation of a map , with a nested map
    # loop over all the availability zones one by one
    # create a map with a key that gets its value from the all_availability_zones list (meaning the AZ names)
    # and the value of: a nested map{
    #   public_cidr & private_cidr as keys
    #   values as the creation is a subnet cidr, for example 10.0.1.0/24
    # }
    all_subnet_pairs = {
        for i, az in local.all_availability_zones :
        az => {
            public_cidr  = cidrsubnet(var.vpc_cidr_block, 8, 0 + i)
            private_cidr = cidrsubnet(var.vpc_cidr_block, 8, 100 + i)
        }
    }
    
    # Separate primary and additional subnet pairs
    # Creation of a map for the primary AZ , that holds the AZ name and the subnet pairs (public & private)
    primary_subnet_pairs = {
        for az in local.primary_azs :
        az => local.all_subnet_pairs[az]
    }
    # Creation of a map for the additional AZs , that holds the AZ names and the subnet pairs (public & private)
    additional_subnet_pairs = {
        for az in local.additional_azs :
        az => local.all_subnet_pairs[az]
    }

    # Private - all subnets
    private_subnet_cidrs = {
        for az, pair in local.all_subnet_pairs : az => pair.private_cidr
    }

    account_id = data.aws_caller_identity.current.account_id

    map_users = {
        for name, user in var.eks_user_access_map : name => {
            userarn  = "arn:aws:iam::${local.account_id}:user/${user.username}"
            username = user.username
            groups   = user.groups
        }
    }
    
    secret_keys = [ 
        var.argocd_aws_secret_key       # e.g., "argocd-secrets"
    ]

    argocd_private_key  = sensitive(base64decode(var.argocd_private_key_b64))
    
    # an AWS managed secret will be created from this with the name: var.argocd_aws_secret_key
    # inside it a json, with key:value pairs
    app_secrets_config = sensitive({
        (var.argocd_aws_secret_key) = {
            description  = "ArgoCD's Github credentials"
            secret_value = jsonencode({
                githubAppID                 = "${var.argocd_app_id}"
                githubAppInstallationID     = "${var.argocd_installation_id}"
                githubAppPrivateKey         = "${local.argocd_private_key}"
                type                        = "git"
                REPO_URL_GITOPS             = "https://github.com/${var.github_org}/${var.github_gitops_repo}"
                REPO_URL_APP                = "https://github.com/${var.github_org}/${var.github_application_repo}"
                argocdOidcClientId          = "${var.github_oauth_client_id}"
                argocdOidcClientSecret      = "${var.github_oauth_client_secret}"
            })
        }
    })

    argocd_service_account_name = "argocd-${var.environment}-service-account"
    argocd_github_sso_secret_name   = "${var.project_tag}-${var.environment}-argocd-github-sso"
    alb_group_name                  = "${var.project_tag}-${var.environment}-alb-shared-group"

    
    autoscaling_group_arns = [
        for asg_name in module.node_groups.autoscaling_group_arns :
        "arn:aws:autoscaling:${var.aws_region}:${local.account_id}:autoScalingGroup:*:autoScalingGroupName/${asg_name}"
    ]

    # Convert short names to full ARNs
    s3_allowed_principal_arns = [
        for principal in var.s3_allowed_principals :
            "arn:aws:iam::${local.account_id}:${principal}"
    ]

    # Merge generated passwords into the configuration
    secrets_config_with_passwords  = {
      for name, config in var.secrets_config :
        name => merge(config, {
            secret_value = config.generate_password ? random_password.generated_passwords[name].result : config.secret_value
        })
    }
}
