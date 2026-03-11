# VPC Module Outputs for Stockfolio EKS Infrastructure

################################################################################
# VPC Outputs
################################################################################

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

################################################################################
# Subnet Outputs
################################################################################

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of public subnets"
  value       = [aws_subnet.public_1.cidr_block, aws_subnet.public_2.cidr_block]
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of private subnets"
  value       = [aws_subnet.private_1.cidr_block, aws_subnet.private_2.cidr_block]
}

################################################################################
# NAT Gateway Outputs
################################################################################

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.main.id
}

################################################################################
# Internet Gateway Outputs
################################################################################

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

################################################################################
# Security Group Outputs
################################################################################

output "eks_cluster_security_group_id" {
  description = "ID of the EKS cluster security group"
  value       = aws_security_group.eks_cluster.id
}

output "eks_nodes_security_group_id" {
  description = "ID of the EKS nodes security group"
  value       = aws_security_group.eks_nodes.id
}

################################################################################
# Route Table Outputs
################################################################################

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = aws_route_table.private.id
}

