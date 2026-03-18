# provider.tf - AWS Provider configuration with default tags and assume role support

provider "aws" {
  region = var.aws_region

  # Default tags applied to all resources
  default_tags {
    tags = {
      Environment     = var.environment
      Project         = var.project_name
      ManagedBy       = "Terraform"
      Owner           = var.owner
      CostCenter      = var.cost_center
      Compliance      = "AWS-Well-Architected"
      SecurityZone    = "private"
      DataClass       = "internal"
      BackupPolicy    = "daily"
      DriftDetection  = "enabled"
      IaCRepo         = var.repository_url
      TerraformModule = "terraform-aws-modules/eks/aws"
    }
  }

  # Optional: Assume role for cross-account or least-privilege access
  # Uncomment and configure if using role assumption
  # assume_role {
  #   role_arn     = "arn:aws:iam::271807748029:role/TerraformExecutionRole"
  #   session_name = "terraform-eks-deployment"
  # }
}

# Kubernetes provider for EKS cluster configuration
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name,
      "--region",
      var.aws_region
    ]
  }
}

# Helm provider for Kubernetes package management
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name,
        "--region",
        var.aws_region
      ]
    }
  }
}
