# main.tf - Main infrastructure configuration for EKS cluster

# ============================================================================
# Data Sources
# ============================================================================

data "aws_caller_identity" "current" {}


# ============================================================================
# KMS Key for EKS Cluster Encryption
# ============================================================================

resource "aws_kms_key" "eks" {
  count = var.enable_cluster_encryption ? 1 : 0

  description             = "KMS key for EKS cluster ${var.cluster_name} envelope encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      },
      {
        Sid    = "AllowAutoScalingEBSEncryption"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowAutoScalingGrants"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        }
        Action   = ["kms:CreateGrant"]
        Resource = "*"
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" = "true"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-eks-encryption-key"
  }
}

resource "aws_kms_alias" "eks" {
  count = var.enable_cluster_encryption ? 1 : 0

  name          = "alias/${var.cluster_name}-eks"
  target_key_id = aws_kms_key.eks[0].key_id
}

# ============================================================================
# VPC Module for Network Infrastructure
# ============================================================================

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  # NAT Gateway configuration
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs for network traffic monitoring
  enable_flow_log                                 = true
  create_flow_log_cloudwatch_iam_role             = true
  create_flow_log_cloudwatch_log_group            = true
  flow_log_cloudwatch_log_group_retention_in_days = var.cloudwatch_log_retention_days

  # Kubernetes-specific tags for subnet discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

# ============================================================================
# Security Group for Additional Node Access Control
# ============================================================================

resource "aws_security_group" "additional" {
  name_prefix = "${var.cluster_name}-additional"
  description = "Additional security group for EKS nodes with strict controls"
  vpc_id      = module.vpc.vpc_id

  # Egress rule - allow all outbound (can be restricted further)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.cluster_name}-additional-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Optional SSH access rule (disabled by default)
resource "aws_security_group_rule" "ssh_access" {
  count = var.enable_node_ssh_access && length(var.allowed_ssh_cidrs) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ssh_cidrs
  security_group_id = aws_security_group.additional.id
  description       = "Allow SSH access from specified CIDRs"
}

# ============================================================================
# IAM Role for EBS CSI Driver (IRSA)
# ============================================================================

module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  count = var.enable_ebs_csi_driver ? 1 : 0

  role_name             = "${var.cluster_name}-ebs-csi-driver"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = {
    Name = "${var.cluster_name}-ebs-csi-irsa-role"
  }
}

# ============================================================================
# EKS Cluster Module
# ============================================================================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Network configuration
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # Cluster endpoint access
  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # Encryption configuration
  cluster_encryption_config = var.enable_cluster_encryption ? {
    resources        = ["secrets"]
    provider_key_arn = aws_kms_key.eks[0].arn
  } : null

  # CloudWatch logging
  cluster_enabled_log_types              = var.cluster_enabled_log_types
  cloudwatch_log_group_retention_in_days = var.cloudwatch_log_retention_days
  cloudwatch_log_group_kms_key_id        = var.enable_cluster_encryption ? aws_kms_key.eks[0].arn : null

  # IRSA (IAM Roles for Service Accounts)
  enable_irsa = var.enable_irsa

  # Cluster addons with specific versions and configuration
  cluster_addons = {
    coredns = var.enable_coredns ? {
      most_recent = true
      configuration_values = jsonencode({
        computeType = "Fargate"
        resources = {
          limits = {
            cpu    = "100m"
            memory = "150Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "150Mi"
          }
        }
      })
    } : null

    vpc-cni = var.enable_vpc_cni ? {
      most_recent              = true
      before_compute           = true
      service_account_role_arn = module.vpc_cni_irsa_role.iam_role_arn
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION          = "true"
          ENABLE_POD_ENI                    = "true"
          POD_SECURITY_GROUP_ENFORCING_MODE = "standard"
        }
      })
    } : null

    kube-proxy = var.enable_kube_proxy ? {
      most_recent = true
    } : null

    aws-ebs-csi-driver = var.enable_ebs_csi_driver ? {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa_role[0].iam_role_arn
    } : null
  }

  # ============================================================================
  # EKS Managed Node Group Configuration
  # ============================================================================

  eks_managed_node_group_defaults = {
    # AMI configuration
    ami_type       = var.node_ami_type
    disk_size      = var.node_disk_size
    disk_type      = var.node_disk_type
    instance_types = var.node_instance_types

    # IAM role configuration
    iam_role_attach_cni_policy = true

    # Metadata options for enhanced security
    metadata_options = {
      http_endpoint               = "enabled"
      http_tokens                 = "required" # Enforce IMDSv2
      http_put_response_hop_limit = 1
      instance_metadata_tags      = "enabled"
    }

    # Update configuration
    update_config = {
      max_unavailable_percentage = 33
    }

    # Additional security groups
    vpc_security_group_ids = [aws_security_group.additional.id]
  }

  eks_managed_node_groups = {
    main = {
      name            = "${var.cluster_name}-${var.node_group_name}"
      use_name_prefix = true

      # Explicit short IAM role name to stay within AWS 38-char name_prefix limit
      iam_role_name            = "${var.cluster_name}-ng-${var.node_group_name}"
      iam_role_use_name_prefix = true

      # Node group sizing
      min_size     = var.node_min_capacity
      max_size     = var.node_max_capacity
      desired_size = var.node_desired_capacity

      # Instance configuration
      capacity_type  = var.node_capacity_type
      instance_types = var.node_instance_types

      # Launch template
      create_launch_template = true
      launch_template_name   = "${var.cluster_name}-${var.node_group_name}-lt"

      # SSH key for nodes (optional)
      key_name = var.enable_node_ssh_access ? var.ssh_key_name : null

      # Block device mappings
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = var.node_disk_size
            volume_type           = var.node_disk_type
            encrypted             = true
            kms_key_id            = var.enable_cluster_encryption ? aws_kms_key.eks[0].arn : null
            delete_on_termination = true
          }
        }
      }

      # Labels for node selection
      labels = {
        Environment = var.environment
        NodeGroup   = var.node_group_name
        WorkerType  = "general-purpose"
      }

      # Taints (none by default)
      taints = []

      # Additional tags
      tags = {
        NodeGroup = var.node_group_name
      }
    }
  }

  # Cluster security group additional rules
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  # Node security group additional rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }

    ingress_cluster_all = {
      description                   = "Cluster to node all ports/protocols"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }

    egress_all = {
      description = "Node all egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = {
    ClusterName = var.cluster_name
  }
}

# ============================================================================
# IAM Role for VPC CNI (IRSA)
# ============================================================================

module "vpc_cni_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${var.cluster_name}-vpc-cni"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = {
    Name = "${var.cluster_name}-vpc-cni-irsa-role"
  }
}

# ============================================================================
# CloudWatch Log Group for Container Insights (Optional)
# ============================================================================

resource "aws_cloudwatch_log_group" "container_insights" {
  count = var.enable_cloudwatch_metrics ? 1 : 0

  name              = "/aws/containerinsights/${var.cluster_name}/performance"
  retention_in_days = var.cloudwatch_log_retention_days
  kms_key_id        = var.enable_cluster_encryption ? aws_kms_key.eks[0].arn : null

  tags = {
    Name = "${var.cluster_name}-container-insights"
  }
}
