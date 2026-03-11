# Production Environment Variables for Stockfolio

variable "project" {
  description = "Project name"
  type        = string
  default     = "stockfolio"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "stockfolio-cluster-prod"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "min_nodes" {
  description = "Minimum number of nodes"
  type        = number
  default     = 2
}

variable "desired_nodes" {
  description = "Desired number of nodes"
  type        = number
  default     = 3
}

variable "max_nodes" {
  description = "Maximum number of nodes"
  type        = number
  default     = 6
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "common_tags" {
  description = "Common tags for AWS resources"
  type        = map(string)
  default = {
    Project     = "stockfolio"
    Environment = "prod"
    ManagedBy   = "Terraform"
    CostCenter  = "Engineering"
  }
}

variable "db_password" {
  description = "MySQL database password"
  type        = string
  sensitive   = true
}

variable "grafana_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

