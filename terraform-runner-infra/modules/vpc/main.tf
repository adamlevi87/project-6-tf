# terraform-main/modules/vpc/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Use first available AZ
  primary_az = data.aws_availability_zones.available.names[0]
  
  # Calculate subnet CIDRs
  public_cidr  = cidrsubnet(var.vpc_cidr_block, 8, 1)   # 10.1.1.0/24
  private_cidr = cidrsubnet(var.vpc_cidr_block, 8, 101) # 10.1.101.0/24
}

# Create the VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = {
    Name        = "${var.project_tag}-${var.environment}-runner-vpc"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "github-runner-infrastructure"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name        = "${var.project_tag}-${var.environment}-runner-igw"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "github-runner-internet-access"
  }
}

# Create Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_cidr
  availability_zone       = local.primary_az
  map_public_ip_on_launch = false
  
  tags = {
    Name        = "${var.project_tag}-${var.environment}-runner-public-subnet"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "nat-gateway"
    Type        = "public"
  }
}

# Create Private Subnet
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.private_cidr
  availability_zone       = local.primary_az
  map_public_ip_on_launch = false
  
  tags = {
    Name        = "${var.project_tag}-${var.environment}-runner-private-subnet"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "github-runner"
    Type        = "private"
  }
}

# Create EIP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  depends_on = [aws_internet_gateway.igw]
  
  tags = {
    Name        = "${var.project_tag}-${var.environment}-runner-nat-eip"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "nat-gateway"
  }
}

# Create NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  
  depends_on    = [aws_internet_gateway.igw]
  
  tags = {
    Name        = "${var.project_tag}-${var.environment}-runner-nat-gw"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "private-subnet-internet-access"
  }
}

# Create Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  tags = {
    Name        = "${var.project_tag}-${var.environment}-runner-public-rt"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "public-subnet-routing"
  }
}

# Create Route Table for Private Subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  
  tags = {
    Name        = "${var.project_tag}-${var.environment}-runner-private-rt"
    Project     = var.project_tag
    Environment = var.environment
    Purpose     = "private-subnet-routing"
  }
}

# Associate Public Subnet with Public Route Table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Associate Private Subnet with Private Route Table
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}