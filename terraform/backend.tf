# Remote state backend — configure per-environment via backend config file.
# Example: terraform init -backend-config=environments/dev/backend.hcl
#
# backend.hcl:
#   bucket         = "secure-access-portal-terraform-state-ACCOUNT_ID"
#   key            = "verified-access/terraform.tfstate"
#   region         = "eu-north-1"
#   encrypt        = true
#   use_lockfile   = true

terraform {
  backend "s3" {
    bucket  = "aws-access-verified-task"
    key     = "verified-access/terraform.tfstate"
    region  = "ap-southeast-2"
    encrypt = true
  }
}
