# terraform-main/modules/github/self_hosted_runner/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

# # Data source for Ubuntu AMI
# data "aws_ami" "ubuntu" {
#   most_recent = true
#   owners      = ["099720109477"] # Canonical

#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd/ubuntu-22.04-amd64-server-*"]
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
# }

data "terraform_remote_state" "main" {
  #count = var.initialize_run ? 0 : 1
  backend = "s3"
  config = {
    bucket = "${var.project_tag}-tf-state"
    key    = "${var.project_tag}-tf/${var.environment}/main/terraform.tfstate"
    region = "${var.aws_region}"
  }
}
resource "null_resource" "validate_outputs_or_fail" {
  #count = var.initialize_run ? 0 : 1

  provisioner "local-exec" {
    command = <<-EOF
      # Check all required outputs for VPC peering
      CLUSTER_NAME="${try(data.terraform_remote_state.main.outputs.eks_cluster_info.cluster_name, "")}"

      if [ -z "$CLUSTER_NAME" ] ; then
        echo "ERROR: Required EKS outputs missing from main terraform state:"
        echo "Cluster Name: $CLUSTER_NAME"
        exit 1
      fi
      
      echo "Validation passed - all required outputs present"
      echo "Cluster Name: $CLUSTER_NAME"
    EOF
  }
}



# User data script to setup GitHub runner
locals {
  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    github_org         = var.github_org
    github_repo        = var.github_repo
    github_token       = var.github_token
    runner_name        = "${var.project_tag}-${var.environment}-runner"
    runner_labels      = join(",", var.runner_labels)
    aws_region         = var.aws_region
    #cluster_name       = var.cluster_name
    #cluster_name       = data.terraform_remote_state.main.outputs.eks_cluster_info.cluster_name
    cluster_name        = try(data.terraform_remote_state.main.outputs.eks_cluster_info.cluster_name, "cluster-not-configured") #cluster-not-configured will not be set, local exec should protect this
    runners_per_instance = var.runners_per_instance
  }))
}

# Security Group for GitHub Runner
resource "aws_security_group" "github_runner" {
  name        = "${var.project_tag}-${var.environment}-github-runner-sg"
  description = "Security group for GitHub self-hosted runner"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_tag}-${var.environment}-github-runner-sg"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "github-runner"
  }
}

# Egress rule - Allow all outbound traffic
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.github_runner.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "All outbound traffic (GitHub API, Docker pulls, AWS APIs, etc.)"
}

# Ingress rule - SSH access (conditional)
resource "aws_security_group_rule" "ingress_ssh" {
  for_each = var.enable_ssh_access ? toset(["ssh"]) : toset([])

  type              = "ingress"
  security_group_id = aws_security_group.github_runner.id
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.ssh_allowed_cidr_blocks
  description       = "SSH access for debugging"
}

# IAM Role for GitHub Runner EC2 instance
resource "aws_iam_role" "github_runner_instance" {
  name = "${var.project_tag}-${var.environment}-github-runner-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
          "ForAllValues:StringEquals" = {
            "aws:PrincipalTag/Purpose" = "github-runner"
            "aws:PrincipalTag/Project" = var.project_tag
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_tag}-${var.environment}-github-runner-instance-role"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "github-runner-instance"
  }
}

# IAM Policy for GitHub Runner (comprehensive permissions for Terraform)
resource "aws_iam_policy" "github_runner_policy" {
  name        = "${var.project_tag}-${var.environment}-github-runner-policy"
  description = "IAM policy for GitHub runner to manage AWS resources via Terraform"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Admin access for Terraform operations
        Effect = "Allow"
        Action = "*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_tag}-${var.environment}-github-runner-policy"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "github-runner-permissions"
  }
}

resource "aws_iam_role_policy_attachment" "github_runner_policy" {
  role       = aws_iam_role.github_runner_instance.name
  policy_arn = aws_iam_policy.github_runner_policy.arn
}

# Instance profile for EC2
resource "aws_iam_instance_profile" "github_runner" {
  name = "${var.project_tag}-${var.environment}-github-runner-profile"
  role = aws_iam_role.github_runner_instance.name

  tags = {
    Name        = "${var.project_tag}-${var.environment}-github-runner-profile"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "github-runner-instance-profile"
  }
}

# Launch Template for GitHub Runner
resource "aws_launch_template" "github_runner" {
  #count = var.initialize_run ? 0 : 1
  name_prefix   = "${var.project_tag}-${var.environment}-github-runner-"
  image_id      = var.ami_id #!= null ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_pair_name

  vpc_security_group_ids = [aws_security_group.github_runner.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.github_runner.name
  }

  user_data = local.user_data

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = var.root_volume_size
      volume_type = "gp3"
      encrypted   = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_tag}-${var.environment}-github-runner"
      Project     = var.project_tag
      Environment = var.environment
      Purpose     = "github-runner"
    }
  }

  tags = {
    Name        = "${var.project_tag}-${var.environment}-github-runner-lt"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "github-runner-launch-template"
  }

  depends_on = [null_resource.validate_outputs_or_fail]
}

# Auto Scaling Group for GitHub Runner
resource "aws_autoscaling_group" "github_runner" {
  #count = var.initialize_run ? 0 : 1
  name                = "${var.project_tag}-${var.environment}-github-runner-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = []
  health_check_type   = "EC2"
  health_check_grace_period = 300

  min_size         = var.min_runners
  max_size         = var.max_runners
  desired_capacity = var.desired_runners

  launch_template {
    id      = aws_launch_template.github_runner.id
    version = "$Latest"
  }

  # Instance refresh on launch template changes
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_tag}-${var.environment}-github-runner"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_tag
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Purpose"
    value               = "github-runner"
    propagate_at_launch = true
  }
}
