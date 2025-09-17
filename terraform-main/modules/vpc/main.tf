# terraform-main/modules/vpc/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
  }
}

locals {
  # Get primary AZ for stable references
  # Create a Variable of AZ name for primary subnet
  primary_az = keys(var.primary_public_subnet_cidrs)[0]
  
  # Determine which subnets need NAT routes
  # on NAT modes real and single, all private subnets require a route
  # on endpoints - no routes will be used (FUTURE WIP)
  subnets_needing_nat = var.nat_mode != "endpoints" ? var.private_subnet_cidrs : {}
}

# Create the VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-vpc"
  }
}

# Create the IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-igw"
  }
}

# Public Subnets are created separetly to support semi-deletion (nat modes)
# Primary public subnets (always exist)
# Create the primary public subnet
resource "aws_subnet" "public_primary" {
  for_each = var.primary_public_subnet_cidrs
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-public-subnet-primary-${each.key}"
    Type        = "primary"
    "kubernetes.io/role/elb" = "1"
  }
}

# Additional public subnets (additional AZs)
resource "aws_subnet" "public_additional" {
  for_each = var.additional_public_subnet_cidrs
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-public-subnet-${each.key}"
    Type        = "additional"
    "kubernetes.io/role/elb" = "1"
  }
}

# Create all the private subnets
resource "aws_subnet" "private" {
  for_each = var.private_subnet_cidrs

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-private-subnet-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Primary public route tables
# Public subnets are routed through the IGW
resource "aws_route_table" "public_primary" {
  for_each = var.primary_public_subnet_cidrs

  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-public-rt-primary-${each.key}"
    Type        = "primary"
  }
}

# Additional public route tables
# Public subnets are routed through the IGW
resource "aws_route_table" "public_additional" {
  for_each = var.additional_public_subnet_cidrs
  
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name        = "${var.project_tag}-public-rt-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
    Type        = "additional"
  }
}

# Primary public route table associations
resource "aws_route_table_association" "public_primary" {
  for_each = aws_subnet.public_primary

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_primary[each.key].id
}

# Additional public route table associations
resource "aws_route_table_association" "public_additional" {
  for_each = aws_subnet.public_additional

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_additional[each.key].id
}

# PRIMARY NAT GATEWAY EIP (always created unless endpoints mode)
resource "aws_eip" "nat_primary" {
  # if nat_mode is anything but endpoints then count=1 and the resource is created
  # else count=0 , and 0 resources are created
  count  = var.nat_mode != "endpoints" ? 1 : 0

  domain = "vpc"
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-nat-eip-primary"
  }
}

# PRIMARY NAT GATEWAY (always created unless endpoints mode)
resource "aws_nat_gateway" "nat_primary" {
  # if nat_mode is anything but endpoints then count=1 and the resource is created
  # else count=0 , and 0 resources are created
  count         = var.nat_mode != "endpoints" ? 1 : 0

  allocation_id = aws_eip.nat_primary[0].id
  subnet_id     = aws_subnet.public_primary[local.primary_az].id
  depends_on    = [aws_internet_gateway.igw]
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-nat-gw-primary"
  }
}

# ADDITIONAL NAT GATEWAYS EIPs (only created in real mode)
resource "aws_eip" "nat_additional" {
  # if nat_mode == 'real' then additional NATs will be created, per AZ 
  # else nothing will be created here
  for_each = var.nat_mode == "real" ? var.additional_public_subnet_cidrs : {}

  domain   = "vpc"
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-nat-eip-${each.key}"
  }
}

# ADDITIONAL NAT GATEWAYS (only created in real mode)
resource "aws_nat_gateway" "nat_additional" {
  # if nat_mode == 'real' then additional NATs will be created, per AZ 
  # else nothing will be created here
  for_each      = var.nat_mode == "real" ? var.additional_public_subnet_cidrs : {}

  allocation_id = aws_eip.nat_additional[each.key].id
  subnet_id     = aws_subnet.public_additional[each.key].id
  depends_on    = [aws_internet_gateway.igw]
  tags = {
    Project     = var.project_tag
    Environment = var.environment
    Name        = "${var.project_tag}-nat-gw-${each.key}"
  }
}

resource "aws_route_table" "private" {
  # for all private subnets [unless the mode is endpoints]
  for_each = local.subnets_needing_nat

  vpc_id = aws_vpc.main.id
  
  # NO inline route blocks - routes managed separately below
  
  tags = {
    Name        = "${var.project_tag}-private-rt-${each.key}"
    Project     = var.project_tag
    Environment = var.environment
  }
}

# VPC module manages its own default NAT routes as separate resources
resource "aws_route" "private_nat_default" {
  for_each = local.subnets_needing_nat

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = (
    # SINGLE mode: all private subnets route to primary NAT
    var.nat_mode == "single" ? aws_nat_gateway.nat_primary[0].id :
    # REAL mode: route to corresponding NAT based on AZ
    var.nat_mode == "real" ? (
      # If this AZ has an additional NAT, use it; 
      # otherwise use primary (should never happen)
      # this might be triple checking and uneeded protection - to avoid terraform plan errors
      contains(keys(aws_nat_gateway.nat_additional), each.key) ? 
        aws_nat_gateway.nat_additional[each.key].id : 
        aws_nat_gateway.nat_primary[0].id
    ) :
    null
  )
}




# # Private route tables with NAT routing
# resource "aws_route_table" "private" {
#   # for all private subnets [unless the mode is endpoints]
#   for_each = local.subnets_needing_nat

#   vpc_id = aws_vpc.main.id
  
#   route {
#     cidr_block     = "0.0.0.0/0"
#     nat_gateway_id = (
#       # SINGLE mode: all private subnets route to primary NAT
#       var.nat_mode == "single" ? aws_nat_gateway.nat_primary[0].id :
#       # REAL mode: route to corresponding NAT based on AZ
#       var.nat_mode == "real" ? (
#         # If this AZ has an additional NAT, use it; 
#         # otherwise use primary (should never happen)
#         # this might be triple checking and uneeded protection - to avoid terraform plan errors
#         contains(keys(aws_nat_gateway.nat_additional), each.key) ? 
#           aws_nat_gateway.nat_additional[each.key].id : 
#           aws_nat_gateway.nat_primary[0].id
#       ) :
#       null
#     )
#   }
#   tags = {
#     Name        = "${var.project_tag}-private-rt-${each.key}"
#     Project     = var.project_tag
#     Environment = var.environment
#   }
# }

# Associate all private subnets with their route tables
resource "aws_route_table_association" "private_subnets" {
  for_each = local.subnets_needing_nat

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}
