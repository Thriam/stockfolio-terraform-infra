# Terraform Providers Configuration for Stockfolio

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

# AWS Provider
provider "aws" {
  region = var.region

  default_tags {
    tags = var.common_tags
  }
}

# Kubernetes Provider - configured after EKS cluster is created
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# Helm Provider
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# AWS EKS Cluster Auth Data
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# Import Kubernetes provider configuration
import {
  id = "stockfolio-cluster"
}

# Variable definitions for providers
variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "common_tags" {
  description = "Common tags for AWS resources"
  type        = map(string)
  default = {
    Project     = "stockfolio"
    ManagedBy   = "Terraform"
  }
}

