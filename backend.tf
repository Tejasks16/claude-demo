# backend.tf - S3 remote state configuration with native locking
# Requires Terraform >= 1.10.0 for S3 native state locking (no DynamoDB needed)
# Run: terraform init -backend-config="bucket=YOUR_BUCKET_NAME"

terraform {
  backend "s3" {
    bucket       = "terraform-state-271807748029-us-east-1"
    key          = "eks/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # Native S3 state locking via conditional writes (Terraform >= 1.10)
  }
}
