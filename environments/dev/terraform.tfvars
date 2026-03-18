# environments/dev/terraform.tfvars - Development environment configuration

# ============================================================================
# General Configuration
# ============================================================================

aws_region     = "us-east-1"
environment    = "dev"
project_name   = "claude-demo"
owner          = "tejas"
cost_center    = "engineering"
repository_url = "https://github.com/Tejasks16/claude-demo"

# ============================================================================
# Network Configuration
# ============================================================================

vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
private_subnets    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnets     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# For dev environment, use single NAT gateway to reduce costs
enable_nat_gateway = true
single_nat_gateway = true  # Set to false for production (multi-AZ redundancy)

# ============================================================================
# EKS Cluster Configuration
# ============================================================================

cluster_name    = "claude-demo-eks-dev"
cluster_version = "1.33"

# API endpoint access configuration
cluster_endpoint_private_access      = true
cluster_endpoint_public_access       = true  # Set to false for production
cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]  # Restrict to your IP ranges in production

# Security features
enable_cluster_encryption = true
enable_irsa               = true

# CloudWatch logging
cluster_enabled_log_types      = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
cloudwatch_log_retention_days  = 30  # Increase for production (90-365 days)
enable_cloudwatch_metrics      = true

# ============================================================================
# EKS Node Group Configuration
# ============================================================================

node_group_name       = "main"
node_instance_types   = ["m5.large"]
node_disk_size        = 50
node_disk_type        = "gp3"
node_ami_type         = "AL2_x86_64"
node_capacity_type    = "ON_DEMAND"  # Use "SPOT" for cost savings in dev

# Auto-scaling configuration
node_desired_capacity = 2
node_min_capacity     = 1
node_max_capacity     = 3

# ============================================================================
# EKS Addons Configuration
# ============================================================================

enable_coredns         = true
enable_vpc_cni         = true
enable_kube_proxy      = true
enable_ebs_csi_driver  = true
enable_efs_csi_driver  = false

# ============================================================================
# Security Configuration
# ============================================================================

# SSH access (disabled by default for security)
enable_node_ssh_access = false
ssh_key_name           = null  # Set to your key pair name if SSH access is needed
allowed_ssh_cidrs      = []    # Add your IP ranges if SSH access is enabled

# ============================================================================
# Monitoring Configuration
# ============================================================================

enable_prometheus = false  # Set to true if you need Prometheus monitoring
