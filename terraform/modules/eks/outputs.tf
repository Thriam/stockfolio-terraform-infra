# EKS Module Outputs for Stockfolio Infrastructure

################################################################################
# Cluster Outputs
################################################################################

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_version" {
  description = "EKS cluster version"
  value       = module.eks.cluster_version
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "EKS cluster CA certificate"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "EKS cluster OIDC issuer URL"
  value       = module.eks.cluster_oidc_issuer_url
}

################################################################################
# Node Group Outputs
################################################################################

output "node_group_role_arn" {
  description = "EKS managed node group role ARN"
  value       = module.eks.node_group_iam_role_arn
}

output "node_security_group_id" {
  description = "EKS node security group ID"
  value       = module.eks.node_security_group_id
}

################################################################################
# IRSA Outputs
################################################################################

output "lb_controller_role_arn" {
  description = "Load Balancer Controller IAM role ARN"
  value       = module.lb_controller_irsa.iam_role_arn
}

output "external_dns_role_arn" {
  description = "External DNS IAM role ARN"
  value       = module.external_dns_irsa.iam_role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "Cluster Autoscaler IAM role ARN"
  value       = module.cluster_autoscaler_irsa.iam_role_arn
}

output "ebs_csi_role_arn" {
  description = "EBS CSI Driver IAM role ARN"
  value       = module.ebs_csi_irsa.iam_role_arn
}

################################################################################
# OIDC Provider
################################################################################

output "oidc_provider_arn" {
  description = "OIDC provider ARN"
  value       = module.eks.oidc_provider_arn
}

