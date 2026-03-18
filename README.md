# AWS EKS Infrastructure - Enterprise-Grade Terraform

Production-ready AWS EKS (Elastic Kubernetes Service) infrastructure using Terraform with enterprise DevOps best practices, zero-trust security principles, and automated CI/CD workflows.

## Architecture Overview

This infrastructure deploys:

- **Private EKS Cluster**: Kubernetes v1.33 with private API endpoint
- **Managed Node Groups**: Auto-scaling (1-3 nodes) with m5.large instances
- **High Availability**: Multi-AZ deployment across 3 availability zones
- **Security**: IRSA, KMS encryption, IMDSv2, VPC isolation
- **Observability**: CloudWatch Logs, Container Insights, VPC Flow Logs
- **Networking**: Private subnets with NAT Gateway, security groups
- **Addons**: CoreDNS, VPC-CNI, kube-proxy, EBS CSI driver

## Prerequisites

- **Terraform**: >= 1.9.0
- **AWS CLI**: >= 2.x
- **kubectl**: >= 1.33
- **AWS Account**: With appropriate IAM permissions
- **GitHub**: Repository with OIDC configured (for CI/CD)

## Quick Start

### 1. Create Remote State Backend

Before initializing Terraform, create the S3 bucket for remote state. Terraform >= 1.10 supports native S3 state locking — no DynamoDB required.

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket terraform-state-271807748029-us-east-1 \
  --region us-east-1

# Enable versioning on the S3 bucket
aws s3api put-bucket-versioning \
  --bucket terraform-state-271807748029-us-east-1 \
  --versioning-configuration Status=Enabled

# Enable encryption on the S3 bucket
aws s3api put-bucket-encryption \
  --bucket terraform-state-271807748029-us-east-1 \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access to the S3 bucket
aws s3api put-public-access-block \
  --bucket terraform-state-271807748029-us-east-1 \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

### 2. Initialize Terraform

```bash
# Navigate to project directory
cd D:/claude-demo

# Initialize Terraform with backend configuration
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive
```

### 3. Deploy Infrastructure

```bash
# Review the execution plan
terraform plan -var-file="environments/dev/terraform.tfvars"

# Apply the configuration
terraform apply -var-file="environments/dev/terraform.tfvars" -auto-approve
```

### 4. Configure kubectl

```bash
# Update kubeconfig to access the EKS cluster
aws eks update-kubeconfig --region us-east-1 --name claude-demo-eks-dev

# Verify cluster access
kubectl get nodes
kubectl get pods -A
```

## Project Structure

```
claude-demo/
├── .github/
│   └── workflows/
│       ├── terraform-pr.yml        # PR validation workflow
│       └── terraform-apply.yml     # Auto-apply on main branch
├── environments/
│   └── dev/
│       └── terraform.tfvars        # Dev environment variables
├── backend.tf                      # S3/DynamoDB backend configuration
├── provider.tf                     # AWS provider with default tags
├── versions.tf                     # Terraform and provider versions
├── variables.tf                    # Input variable definitions
├── main.tf                         # Main EKS infrastructure
├── outputs.tf                      # Output values
├── README.md                       # This file
└── .gitignore                      # Git ignore patterns
```

## Key Features

### Security

- **Zero-Trust Architecture**: No hardcoded credentials, OIDC authentication
- **Encryption at Rest**: KMS encryption for EKS secrets, EBS volumes
- **Encryption in Transit**: TLS for all communication
- **IMDSv2**: Enforced on all EC2 instances
- **Private Cluster**: API endpoint accessible only via private subnet
- **IRSA**: IAM Roles for Service Accounts for pod-level permissions
- **Security Groups**: Least-privilege network access controls
- **VPC Isolation**: Private subnets for workloads

### High Availability

- **Multi-AZ**: Resources distributed across 3 availability zones
- **Auto-Scaling**: Node groups scale 1-3 nodes based on demand
- **NAT Gateway**: Redundant NAT gateways (optional)
- **EBS CSI**: Dynamic volume provisioning with replication

### Observability

- **CloudWatch Logs**: Control plane logs (API, audit, etc.)
- **Container Insights**: Pod and node metrics
- **VPC Flow Logs**: Network traffic monitoring
- **Log Retention**: 30 days (configurable)

### Compliance

- **AWS Well-Architected**: Follows best practices
- **Tagging Strategy**: Comprehensive resource tagging
- **Drift Detection**: Automated in CI/CD pipeline
- **Security Scanning**: Trivy and tflint in PR checks

## CI/CD Workflows

### Pull Request Workflow (`terraform-pr.yml`)

Triggered on PRs to main branch:

1. **Code Quality**: terraform fmt, validate
2. **Security Scanning**: Trivy vulnerability scan, tflint
3. **Plan Generation**: terraform plan with drift detection
4. **PR Comment**: Post plan output to PR
5. **Claude Review**: AI-powered code review (optional)

### Apply Workflow (`terraform-apply.yml`)

Triggered on push to main branch:

1. **OIDC Authentication**: No long-lived credentials
2. **Auto-Apply**: Automatically apply changes
3. **Output Display**: Show cluster details
4. **Notification**: Report status

## GitHub OIDC Setup

To enable OIDC authentication for GitHub Actions:

### 1. Create IAM OIDC Provider

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 2. Create IAM Role for GitHub Actions

Create a file `github-actions-trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::271807748029:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:your-org/claude-demo:*"
        }
      }
    }
  ]
}
```

Create the IAM role:

```bash
# Create IAM role
aws iam create-role \
  --role-name GitHubActionsEKSDeployment \
  --assume-role-policy-document file://github-actions-trust-policy.json

# Attach policies (adjust based on least-privilege principle)
aws iam attach-role-policy \
  --role-name GitHubActionsEKSDeployment \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

### 3. Update GitHub Secrets

Add these secrets to your GitHub repository:

- `AWS_ROLE_ARN`: `arn:aws:iam::271807748029:role/GitHubActionsEKSDeployment`
- `AWS_REGION`: `us-east-1`

## Common Operations

### Scaling Node Group

Update `environments/dev/terraform.tfvars`:

```hcl
node_desired_capacity = 3
node_min_capacity     = 2
node_max_capacity     = 5
```

Then apply:

```bash
terraform apply -var-file="environments/dev/terraform.tfvars"
```

### Upgrading Kubernetes Version

Update `cluster_version` in `environments/dev/terraform.tfvars`:

```hcl
cluster_version = "1.34"
```

Apply changes:

```bash
terraform apply -var-file="environments/dev/terraform.tfvars"
```

### Viewing Cluster Logs

```bash
# View control plane logs
aws logs tail /aws/eks/claude-demo-eks-dev/cluster --follow

# View Container Insights logs
aws logs tail /aws/containerinsights/claude-demo-eks-dev/performance --follow
```

### Accessing Cluster

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name claude-demo-eks-dev

# Get cluster info
kubectl cluster-info

# Get nodes
kubectl get nodes -o wide

# Get all resources
kubectl get all -A
```

## Destroying Infrastructure

⚠️ **WARNING**: This will permanently delete all resources.

```bash
# Review what will be destroyed
terraform plan -destroy -var-file="environments/dev/terraform.tfvars"

# Destroy infrastructure
terraform destroy -var-file="environments/dev/terraform.tfvars" -auto-approve
```

### Cleanup Remote State (Optional)

```bash
# Delete S3 bucket (must be empty)
aws s3 rm s3://terraform-state-271807748029-us-east-1 --recursive
aws s3api delete-bucket \
  --bucket terraform-state-271807748029-us-east-1 \
  --region us-east-1
```

## Cost Estimation

Approximate monthly costs (us-east-1):

- **EKS Control Plane**: $73/month
- **EC2 Instances (2x m5.large)**: ~$140/month
- **NAT Gateway**: ~$32/month (single) or ~$96/month (multi-AZ)
- **EBS Volumes (100 GB)**: ~$10/month
- **Data Transfer**: Variable
- **CloudWatch Logs**: ~$5-20/month

**Total**: ~$260-340/month for dev environment

## Troubleshooting

### Issue: Cluster endpoint not accessible

```bash
# Check security groups
aws eks describe-cluster --name claude-demo-eks-dev \
  --query 'cluster.resourcesVpcConfig.securityGroupIds'

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name claude-demo-eks-dev
```

### Issue: Nodes not joining cluster

```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name claude-demo-eks-dev \
  --nodegroup-name main

# View CloudWatch logs
aws logs tail /aws/eks/claude-demo-eks-dev/cluster --follow
```

### Issue: Terraform state lock

```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

## Best Practices

1. **Never commit sensitive data**: Use `.gitignore` for tfvars files
2. **Use OIDC**: Avoid long-lived AWS credentials
3. **Enable drift detection**: Run regular terraform plan checks
4. **Tag everything**: Use consistent tagging strategy
5. **Least privilege**: Grant minimal IAM permissions
6. **Multi-AZ**: Deploy across availability zones
7. **Backup state**: Enable S3 versioning
8. **Monitor costs**: Set up AWS Budgets and Cost Anomaly Detection
9. **Security scanning**: Integrate Trivy, tflint in CI/CD
10. **Immutable infrastructure**: Replace rather than modify

## Contributing

1. Create a feature branch
2. Make changes
3. Submit PR (triggers validation workflow)
4. Address review comments
5. Merge to main (triggers auto-apply)

## Support

For issues and questions:

- GitHub Issues: [your-org/claude-demo/issues](https://github.com/your-org/claude-demo/issues)
- Documentation: [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- Terraform Registry: [terraform-aws-modules/eks/aws](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)

## License

MIT License - See LICENSE file for details

---

**Generated with Claude Code** | **AWS Well-Architected** | **Zero-Trust Security**
