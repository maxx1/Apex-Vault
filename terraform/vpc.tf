# =============================================================================
# VPC & Networking
# =============================================================================
# Demonstrates network isolation and multi-AZ architecture.
#
# Design Note: Lambda in this project accesses only AWS-managed services
# (S3, CloudWatch) via public endpoints, so it doesn't require VPC access.
# The VPC is provisioned to support future compute resources (ECS, RDS, etc.)
# that WOULD require private network isolation.
#
# In production, add:
# - NAT Gateway for private subnet internet access (~$32/month)
# - VPC endpoints for S3 and CloudWatch (avoids NAT costs for AWS traffic)
# - Network ACLs as a second layer of network security
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

# --- Availability Zones ---
data "aws_availability_zones" "available" {
  state = "available"
}

# --- Public Subnets (Multi-AZ) ---
# Used for: Load Balancers, NAT Gateways, bastion hosts
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-public-${data.aws_availability_zones.available.names[count.index]}"
    Tier = "public"
  }
}

# --- Private Subnets (Multi-AZ) ---
# Used for: Application servers, databases, Lambda (when VPC access is needed)
# NOTE: No NAT Gateway in dev to save costs (~$32/month).
# Add a NAT Gateway in staging/prod for private subnet internet access.
resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-${var.environment}-private-${data.aws_availability_zones.available.names[count.index]}"
    Tier = "private"
  }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# --- Public Route Table ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Private Route Table ---
# No internet route — private subnets are fully isolated.
# In production, add: NAT Gateway route for outbound internet access.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
