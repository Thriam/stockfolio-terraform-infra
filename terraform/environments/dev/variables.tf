# Development Environment Variables for Stockfolio

variable "project" {
  description = "Project name"
  type        = string
  default     = "stockfolio"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "stockfolio-cluster"
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
  default     = 1
}

variable "desired_nodes" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "max_nodes" {
  description = "Maximum number of nodes"
  type        = number
  default     = 4
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "common_tags" {
  description = "Common tags for AWS resources"
  type        = map(string)
  default = {
    Project     = "stockfolio"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

variable "db_password" {
  description = "MySQL database password"
  type        = string
  default     = "stockfolio123"
  sensitive   = true
}

variable "grafana_password" {
  description = "Grafana admin password"
  type        = string
  default     = "admin123"
  sensitive   = true
}

