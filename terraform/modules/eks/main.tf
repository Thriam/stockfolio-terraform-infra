# EKS Module for Stockfolio Infrastructure
# Creates EKS cluster with managed node groups using terraform-aws-modules/eks/aws

terraform {
  required_version = ">= 1.5"
}

################################################################################
# EKS Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id                         = var.vpc_id
  subnet_ids                     = var.private_subnet_ids
  cluster_endpoint_public_access = true

  # EKS Managed Node Group - Primary
  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = [var.instance_type]

    attach_cluster_primary_security_group = true
  }

  eks_managed_node_groups = {
    primary = {
      name = "stockfolio-node-group"

      instance_types = [var.instance_type]

      min_size     = var.min_nodes
      max_size     = var.max_nodes
      desired_size = var.desired_nodes

      vpc_subnet_ids = var.private_subnet_ids

      labels = {
        Environment = var.environment
        Project     = var.project
      }

      tags = {
        "k8s.io/cluster-autoscaler/enabled" = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
      }
    }
  }

  # Tags for all resources
  tags = var.common_tags
}

################################################################################
# AWS Load Balancer Controller IAM Role (IRSA)
################################################################################

data "aws_iam_policy" "aws_lb_controller" {
  arn = "arn:aws:iam::aws:policy/AWSLoadBalancerControllerIAMPolicy"
}

module "lb_controller_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/role-for-service-accounts-eks"

  role_name = "${var.cluster_name}-lb-controller"

  role_policy_arns = {
    aws_load_balancer_controller = data.aws_iam_policy.aws_lb_controller.arn
  }

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = var.common_tags
}

################################################################################
# External DNS IAM Role (IRSA)
################################################################################

data "aws_iam_policy" "external_dns" {
  arn = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
}

module "external_dns_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/role-for-service-accounts-eks"

  role_name = "${var.cluster_name}-external-dns"

  role_policy_arns = {
    external_dns = data.aws_iam_policy.external_dns.arn
  }

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:external-dns"]
    }
  }

  tags = var.common_tags
}

################################################################################
# Cluster Autoscaler IAM Role (IRSA)
################################################################################

module "cluster_autoscaler_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/role-for-service-accounts-eks"

  role_name = "${var.cluster_name}-cluster-autoscaler"

  role_policy_arns = {
    cluster_autoscaler = "arn:aws:iam::aws:policy/autoscaling:DescribeAutoScalingGroups"
  }

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }

  tags = var.common_tags
}

################################################################################
# EBS CSI Driver IAM Role (IRSA)
################################################################################

data "aws_iam_policy" "ebs_csi_driver" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "ebs_csi_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/role-for-service-accounts-eks"

  role_name = "${var.cluster_name}-ebs-csi"

  role_policy_arns = {
    ebs_csi = data.aws_iam_policy.ebs_csi_driver.arn
  }

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.common_tags
}

