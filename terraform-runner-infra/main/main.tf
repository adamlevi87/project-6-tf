# terraform-runner-infra/main/main.tf

# VPC Module - Simple single AZ setup
module "vpc" {
  source = "../modules/vpc"

  project_tag    = var.project_tag
  environment    = var.environment
  
  vpc_cidr_block = var.vpc_cidr_block
}

#GitHub Self-Hosted Runner Module
module "github_runner" {
  # False = normal run
  # True = minimal run- dont create
  #count = var.initialize_run ? 0 : 1

  source = "../modules/github/self_hosted_runner"

  project_tag = var.project_tag
  environment = var.environment
  initialize_run = var.initialize_run

  # Network configuration
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # GitHub configuration
  github_org   = var.github_org
  github_repo  = var.github_terraform_repo
  github_token = var.github_token
  aws_region   = var.aws_region
  #cluster_name = var.cluster_name # Will be empty initially, updated after main project deploys

  # Instance configuration
  instance_type    = var.runner_instance_type
  ami_id          = var.runner_ami_id
  key_pair_name   = var.key_pair_name
  root_volume_size = var.runner_root_volume_size

  # Scaling configuration
  min_runners     = var.min_runners
  max_runners     = var.max_runners
  desired_runners = var.desired_runners

  # Runner configuration
  runner_labels = var.runner_labels
  runners_per_instance = var.runners_per_instance

  # SSH access (for debugging)
  enable_ssh_access       = var.enable_ssh_access
  ssh_allowed_cidr_blocks = var.ssh_allowed_cidr_blocks

  depends_on = [module.vpc]
}

module "vpc_peering" {
  # False = normal run
  # True = minimal run- dont create
  #count = var.initialize_run ? 0 : 1
  
  source = "../modules/vpc_peering"

  initialize_run = var.initialize_run
  project_tag = var.project_tag
  environment = var.environment
  aws_region = var.aws_region

  # Source VPC (runner infrastructure)
  source_vpc_id              = module.vpc.vpc_id
  source_route_table_id      = module.vpc.private_route_table_id

  # Peer VPC (main project)
  #peer_vpc_id   = var.main_vpc_id
  #peer_vpc_cidr = var.main_vpc_cidr
  #peer_region   = var.aws_region

  depends_on = [module.vpc]
}
