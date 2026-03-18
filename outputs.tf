# outputs.tf - Output values for EKS cluster and related resources

# ============================================================================
# VPC Outputs
# ============================================================================

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "nat_gateway_ips" {
  description = "List of Elastic IPs associated with NAT gateways"
  value       = module.vpc.nat_public_ips
}

# ============================================================================
# EKS Cluster Outputs
# ============================================================================

output "cluster_id" {
  description = "The ID of the EKS cluster"
  value       = module.eks.cluster_id
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  value       = module.eks.cluster_version
}

output "cluster_platform_version" {
  description = "The platform version for the EKS cluster"
  value       = module.eks.cluster_platform_version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = module.eks.node_security_group_id
}

# ============================================================================
# OIDC Provider Outputs
# ============================================================================

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider" {
  description = "The OpenID Connect identity provider (issuer URL without leading `https://`)"
  value       = module.eks.oidc_provider
}

# ============================================================================
# EKS Managed Node Group Outputs
# ============================================================================

output "eks_managed_node_groups" {
  description = "Map of attribute maps for all EKS managed node groups"
  value       = module.eks.eks_managed_node_groups
}

output "eks_managed_node_groups_autoscaling_group_names" {
  description = "List of the autoscaling group names created by EKS managed node groups"
  value       = module.eks.eks_managed_node_groups_autoscaling_group_names
}

# ============================================================================
# IAM Role Outputs
# ============================================================================

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = module.eks.cluster_iam_role_arn
}

output "node_iam_role_arn" {
  description = "IAM role ARN of the EKS nodes"
  value       = module.eks.eks_managed_node_groups["main"].iam_role_arn
}

output "ebs_csi_driver_role_arn" {
  description = "IAM role ARN for EBS CSI driver"
  value       = var.enable_ebs_csi_driver ? module.ebs_csi_irsa_role[0].iam_role_arn : null
}

output "vpc_cni_role_arn" {
  description = "IAM role ARN for VPC CNI"
  value       = module.vpc_cni_irsa_role.iam_role_arn
}

# ============================================================================
# Cluster Addons Outputs
# ============================================================================

output "cluster_addons" {
  description = "Map of attribute maps for all EKS cluster addons enabled"
  value       = module.eks.cluster_addons
}

# ============================================================================
# KMS Key Outputs
# ============================================================================

output "kms_key_id" {
  description = "The globally unique identifier for the KMS key"
  value       = var.enable_cluster_encryption ? aws_kms_key.eks[0].key_id : null
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for cluster encryption"
  value       = var.enable_cluster_encryption ? aws_kms_key.eks[0].arn : null
}

# ============================================================================
# CloudWatch Outputs
# ============================================================================

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for EKS cluster logs"
  value       = module.eks.cloudwatch_log_group_name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for EKS cluster logs"
  value       = module.eks.cloudwatch_log_group_arn
}

# ============================================================================
# Kubectl Configuration Command
# ============================================================================

output "configure_kubectl" {
  description = "Command to configure kubectl to access the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# ============================================================================
# Additional Useful Outputs
# ============================================================================

output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}
