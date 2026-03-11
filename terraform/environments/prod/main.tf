# Stockfolio Production Environment - Main Terraform Configuration
# This configuration creates the complete infrastructure for the Stockfolio application in production

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
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }

  # Remote backend configuration
  backend "s3" {
    bucket         = "stockfolio-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "stockfolio-terraform-locks"
  }
}

################################################################################
# Variables
################################################################################

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

################################################################################
# AWS Provider
################################################################################

provider "aws" {
  region = var.region

  default_tags {
    tags = var.common_tags
  }
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "../../modules/vpc"

  project        = var.project
  environment    = var.environment
  region         = var.region
  vpc_cidr       = var.vpc_cidr
  cluster_name   = var.cluster_name
  common_tags    = var.common_tags

  availability_zones     = ["ap-south-1a", "ap-south-1b"]
  public_subnet_cidrs    = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs  = ["10.1.10.0/24", "10.1.20.0/24"]
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source = "../../modules/eks"

  project            = var.project
  environment        = var.environment
  region             = var.region
  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  instance_type   = var.instance_type
  min_nodes       = var.min_nodes
  desired_nodes   = var.desired_nodes
  max_nodes       = var.max_nodes

  common_tags = var.common_tags
}

################################################################################
# Kubernetes Provider
################################################################################

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.cluster.token

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# Helm Provider
provider "helm" {
  repository_config_path = "${path.module}/.helm"
  repository_cache_path  = "${path.module}/.helm"

  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.cluster.token

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# Kubectl Provider
provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.cluster.token

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# AWS EKS Cluster Auth
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

################################################################################
# AWS Load Balancer Controller - Helm Release
################################################################################

resource "helm_release" "aws_load_balancer_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  namespace        = "kube-system"
  create_namespace = true
  version          = "1.6.2"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks.lb_controller_role_arn
  }

  depends_on = [module.eks]
}

################################################################################
# External DNS - Helm Release
################################################################################

resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns"
  chart            = "external-dns"
  namespace        = "kube-system"
  create_namespace = true
  version          = "1.13.1"

  set {
    name  = "provider.aws"
    value = "true"
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks.external_dns_role_arn
  }

  depends_on = [module.eks]
}

################################################################################
# Cluster Autoscaler - Helm Release
################################################################################

resource "helm_release" "cluster_autoscaler" {
  name             = "cluster-autoscaler"
  repository       = "https://kubernetes.github.io/autoscaler"
  chart            = "cluster-autoscaler"
  namespace        = "kube-system"
  create_namespace = true
  version          = "9.34.1"

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.region
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks.cluster_autoscaler_role_arn
  }

  depends_on = [module.eks]
}

################################################################################
# EBS CSI Driver - Helm Release
################################################################################

resource "helm_release" "ebs_csi_driver" {
  name             = "aws-ebs-csi-driver"
  repository       = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart            = "aws-ebs-csi-driver"
  namespace        = "kube-system"
  create_namespace = true
  version          = "2.22.0"

  set {
    name  = "controller.serviceAccount.create"
    value = "false"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "ebs-csi-controller-sa"
  }

  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks.ebs_csi_role_arn
  }

  depends_on = [module.eks]
}

################################################################################
# Prometheus and Grafana - Helm Release
################################################################################

resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  namespace        = "monitoring"
  create_namespace = true
  version          = "25.8.0"

  set {
    name  = "alertmanager.persistentVolume.enabled"
    value = "true"
  }

  set {
    name  = "server.persistentVolume.enabled"
    value = "true"
  }

  set {
    name  = "server.retention"
    value = "30d"
  }

  set {
    name  = "server.replicas"
    value = "2"
  }

  depends_on = [module.eks]
}

resource "helm_release" "grafana" {
  name             = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "grafana"
  namespace        = "monitoring"
  create_namespace = true
  version          = "6.58.9"

  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "persistence.size"
    value = "20Gi"
  }

  set {
    name  = "replicas"
    value = "2"
  }

  set {
    name  = "adminPassword"
    value = var.grafana_password
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].name"
    value = "Prometheus"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].type"
    value = "prometheus"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].url"
    value = "http://prometheus-server.monitoring.svc.cluster.local"
  }

  depends_on = [helm_release.prometheus]
}

################################################################################
# Kubernetes Namespaces
################################################################################

resource "kubernetes_namespace" "app" {
  metadata {
    name = "stockfolio"
    labels = {
      "name" = "stockfolio"
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "name" = "monitoring"
    }
  }
}

################################################################################
# Kubernetes Deployments and Services
################################################################################

locals {
  app_namespace = "stockfolio"
}

# MySQL Deployment
resource "kubernetes_deployment" "mysql" {
  metadata {
    name      = "mysql"
    namespace = local.app_namespace
    labels = {
      app = "mysql"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mysql"
      }
    }

    template {
      metadata {
        labels = {
          app = "mysql"
        }
      }

      spec {
        container {
          name  = "mysql"
          image = "mysql:8.0"

          env {
            name  = "MYSQL_ROOT_PASSWORD"
            value = "rootpassword"
          }

          env {
            name  = "MYSQL_DATABASE"
            value = "stockfolio"
          }

          env {
            name  = "MYSQL_USER"
            value = "stockfolio"
          }

          env {
            name  = "MYSQL_PASSWORD"
            value = var.db_password
          }

          port {
            container_port = 3306
            name           = "mysql"
          }

          volume_mount {
            name       = "mysql-persistent-storage"
            mount_path = "/var/lib/mysql"
          }

          resources {
            requests = {
              cpu    = "500m"
              memory = "1Gi"
            }
            limits = {
              cpu    = "1000m"
              memory = "2Gi"
            }
          }
        }

        volume {
          name = "mysql-persistent-storage"

          persistent_volume_claim {
            claim_name = "mysql-pvc"
            read_only  = false
          }
        }
      }
    }
  }

  depends_on = [helm_release.ebs_csi_driver]
}

# MySQL Service
resource "kubernetes_service" "mysql" {
  metadata {
    name      = "mysql"
    namespace = local.app_namespace
  }

  spec {
    selector = {
      app = "mysql"
    }

    port {
      port        = 3306
      target_port = 3306
      name        = "mysql"
    }

    type = "ClusterIP"
  }
}

# MySQL PersistentVolumeClaim
resource "kubernetes_persistent_volume_claim" "mysql" {
  metadata {
    name      = "mysql-pvc"
    namespace = local.app_namespace
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "gp3"

    resources {
      requests = {
        storage = "50Gi"
      }
    }
  }

  depends_on = [helm_release.ebs_csi_driver]
}

# Backend Deployment
resource "kubernetes_deployment" "backend" {
  metadata {
    name      = "backend"
    namespace = local.app_namespace
    labels = {
      app = "backend"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "backend"
      }
    }

    template {
      metadata {
        labels = {
          app = "backend"
        }
      }

      spec {
        container {
          name  = "backend"
          image = "navlipi/stockfolio-backend:latest"

          port {
            container_port = 8080
            name           = "backend"
          }

          env {
            name  = "DB_HOST"
            value = "mysql.stockfolio.svc.cluster.local"
          }

          env {
            name  = "DB_PORT"
            value = "3306"
          }

          env {
            name  = "DB_NAME"
            value = "stockfolio"
          }

          env {
            name  = "DB_USER"
            value = "stockfolio"
          }

          env {
            name  = "DB_PASSWORD"
            value = var.db_password
          }

          resources {
            requests = {
              cpu    = "500m"
              memory = "1Gi"
            }
            limits = {
              cpu    = "1000m"
              memory = "2Gi"
            }
          }
        }
      }
    }
  }
}

# Backend Service
resource "kubernetes_service" "backend" {
  metadata {
    name      = "backend"
    namespace = local.app_namespace
  }

  spec {
    selector = {
      app = "backend"
    }

    port {
      port        = 8080
      target_port = 8080
      name        = "backend"
    }

    type = "ClusterIP"
  }
}

# Frontend Deployment
resource "kubernetes_deployment" "frontend" {
  metadata {
    name      = "frontend"
    namespace = local.app_namespace
    labels = {
      app = "frontend"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "frontend"
      }
    }

    template {
      metadata {
        labels = {
          app = "frontend"
        }
      }

      spec {
        container {
          name  = "frontend"
          image = "navlipi/stockfolio-frontend:latest"

          port {
            container_port = 80
            name           = "http"
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      }
    }
  }
}

# Frontend Service
resource "kubernetes_service" "frontend" {
  metadata {
    name      = "frontend"
    namespace = local.app_namespace
  }

  spec {
    selector = {
      app = "frontend"
    }

    port {
      port        = 80
      target_port = 80
      name        = "http"
    }

    type = "ClusterIP"
  }
}

# Wallet Deployment
resource "kubernetes_deployment" "wallet" {
  metadata {
    name      = "wallet"
    namespace = local.app_namespace
    labels = {
      app = "wallet"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "wallet"
      }
    }

    template {
      metadata {
        labels = {
          app = "wallet"
        }
      }

      spec {
        container {
          name  = "wallet"
          image = "navlipi/stockfolio-wallet:latest"

          port {
            container_port = 8091
            name           = "wallet"
          }

          env {
            name  = "DB_HOST"
            value = "mysql.stockfolio.svc.cluster.local"
          }

          env {
            name  = "DB_PORT"
            value = "3306"
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
          }
        }
      }
    }
  }
}

# Wallet Service
resource "kubernetes_service" "wallet" {
  metadata {
    name      = "wallet"
    namespace = local.app_namespace
  }

  spec {
    selector = {
      app = "wallet"
    }

    port {
      port        = 8091
      target_port = 8091
      name        = "wallet"
    }

    type = "ClusterIP"
  }
}

# About Deployment
resource "kubernetes_deployment" "about" {
  metadata {
    name      = "about"
    namespace = local.app_namespace
    labels = {
      app = "about"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "about"
      }
    }

    template {
      metadata {
        labels = {
          app = "about"
        }
      }

      spec {
        container {
          name  = "about"
          image = "navlipi/stockfolio-about:latest"

          port {
            container_port = 8090
            name           = "about"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }
}

# About Service
resource "kubernetes_service" "about" {
  metadata {
    name      = "about"
    namespace = local.app_namespace
  }

  spec {
    selector = {
      app = "about"
    }

    port {
      port        = 8090
      target_port = 8090
      name        = "about"
    }

    type = "ClusterIP"
  }
}

# Market Data Deployment
resource "kubernetes_deployment" "market_data" {
  metadata {
    name      = "market-data"
    namespace = local.app_namespace
    labels = {
      app = "market-data"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "market-data"
      }
    }

    template {
      metadata {
        labels = {
          app = "market-data"
        }
      }

      spec {
        container {
          name  = "market-data"
          image = "navlipi/stockfolio-market-data:latest"

          port {
            container_port = 7666
            name           = "market-data"
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
          }
        }
      }
    }
  }
}

# Market Data Service
resource "kubernetes_service" "market_data" {
  metadata {
    name      = "market-data"
    namespace = local.app_namespace
  }

  spec {
    selector = {
      app = "market-data"
    }

    port {
      port        = 7666
      target_port = 7666
      name        = "market-data"
    }

    type = "ClusterIP"
  }
}

################################################################################
# Horizontal Pod Autoscaling
################################################################################

resource "kubernetes_horizontal_pod_autoscaler" "backend_hpa" {
  metadata {
    name      = "backend-hpa"
    namespace = local.app_namespace
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "backend"
    }

    min_replicas = 2
    max_replicas = 10

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = "70"
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = "80"
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "frontend_hpa" {
  metadata {
    name      = "frontend-hpa"
    namespace = local.app_namespace
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "frontend"
    }

    min_replicas = 2
    max_replicas = 10

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = "70"
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "wallet_hpa" {
  metadata {
    name      = "wallet-hpa"
    namespace = local.app_namespace
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "wallet"
    }

    min_replicas = 1
    max_replicas = 8

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = "70"
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "market_data_hpa" {
  metadata {
    name      = "market-data-hpa"
    namespace = local.app_namespace
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "market-data"
    }

    min_replicas = 1
    max_replicas = 8

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = "70"
        }
      }
    }
  }
}

################################################################################
# ALB Ingress
################################################################################

resource "kubernetes_ingress_v1" "stockfolio_alb" {
  metadata {
    name      = "stockfolio-ingress"
    namespace = local.app_namespace
    annotations = {
      "kubernetes.io/ingress.class"                      = "alb"
      "alb.ingress.kubernetes.io/scheme"                 = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"            = "ip"
      "alb.ingress.kubernetes.io/ssl-policy"             = "ELBSecurityPolicy-2016-08"
      "alb.ingress.kubernetes.io/listen-ports"          = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
      "alb.ingress.kubernetes.io/certificate-arn"        = ""
      "alb.ingress.kubernetes.io/ssl-redirect"           = "true"
      "external-dns.alpha.kubernetes.io/hostname"        = "stockfolio.example.com"
      "external-dns.alpha.kubernetes.io/ttl"            = "60"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "frontend"

              port {
                number = 80
              }
            }
          }
        }

        path {
          path      = "/api"
          path_type = "Prefix"

          backend {
            service {
              name = "backend"

              port {
                number = 8080
              }
            }
          }
        }

        path {
          path      = "/wallet"
          path_type = "Prefix"

          backend {
            service {
              name = "wallet"

              port {
                number = 8091
              }
            }
          }
        }

        path {
          path      = "/about"
          path_type = "Prefix"

          backend {
            service {
              name = "about"

              port {
                number = 8090
              }
            }
          }
        }

        path {
          path      = "/market-data"
          path_type = "Prefix"

          backend {
            service {
              name = "market-data"

              port {
                number = 7666
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.aws_load_balancer_controller, helm_release.external_dns]
}

################################################################################
# Outputs
################################################################################

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "EKS cluster version"
  value       = module.eks.cluster_version
}

output "node_group_role_arn" {
  description = "Node group IAM role ARN"
  value       = module.eks.node_group_role_arn
}

output "lb_controller_role_arn" {
  description = "Load Balancer Controller IAM role ARN"
  value       = module.eks.lb_controller_role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "Cluster Autoscaler IAM role ARN"
  value       = module.eks.cluster_autoscaler_role_arn
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://grafana.monitoring.svc.cluster.local"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://prometheus-server.monitoring.svc.cluster.local"
}

