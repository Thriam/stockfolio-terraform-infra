# VPC Module for Stockfolio EKS Infrastructure
# Creates a VPC with public and private subnets across 2 availability zones

terraform {
  required_version = ">= 1.5"
}

################################################################################
# VPC Configuration
################################################################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project}-vpc"
    }
  )
}

################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project}-igw"
    }
  )
}

################################################################################
# Public Subnets
################################################################################

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[0]
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name                                        = "${var.project}-public-subnet-1"
      "kubernetes.io/role/elb"                    = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[1]
  availability_zone       = var.availability_zones[1]
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name                                        = "${var.project}-public-subnet-2"
      "kubernetes.io/role/elb"                    = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

################################################################################
# Private Subnets (for worker nodes)
################################################################################

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[0]
  availability_zone = var.availability_zones[0]

  tags = merge(
    var.common_tags,
    {
      Name                                        = "${var.project}-private-subnet-1"
      "kubernetes.io/role/internal-elb"          = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[1]
  availability_zone = var.availability_zones[1]

  tags = merge(
    var.common_tags,
    {
      Name                                        = "${var.project}-private-subnet-2"
      "kubernetes.io/role/internal-elb"          = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

################################################################################
# Elastic IP for NAT Gateway
################################################################################

resource "aws_eip" "nat_gateway_1" {
  domain = "vpc"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project}-eip-1"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

################################################################################
# NAT Gateway
################################################################################

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat_gateway_1.id
  subnet_id     = aws_subnet.public_1.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project}-nat-gw"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

################################################################################
# Route Tables
################################################################################

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project}-public-rt"
    }
  )
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project}-private-rt"
    }
  )
}

################################################################################
# Route Table Associations
################################################################################

# Public Subnet Associations
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Private Subnet Associations
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

################################################################################
# Security Groups
################################################################################

# EKS Cluster Security Group
resource "aws_security_group" "eks_cluster" {
  name        = "${var.project}-eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow Kubernetes API"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project}-eks-cluster-sg"
    }
  )
}

# EKS Node Security Group
resource "aws_security_group" "eks_nodes" {
  name        = "${var.project}-eks-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow worker nodes to communicate with cluster"
    from_port   = 1025
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project}-eks-nodes-sg"
    }
  )
}

