# Remote state backend — configure per-environment via backend config file.
# Example: terraform init -backend-config=environments/dev/backend.hcl
#
# backend.hcl:
#   bucket         = "secure-access-portal-terraform-state-ACCOUNT_ID"
#   key            = "verified-access/terraform.tfstate"
#   region         = "ap-south-1"
#   encrypt        = true
#   use_lockfile   = true
#   kms_key_id     = "arn:aws:kms:ap-south-1:ACCOUNT_ID:key/KEY_ID"

terraform {
  backend "s3" {
    name         = "aws-access-verified-task "
    key          = "verified-access/terraform.tfstate"  
    region       = "eu-north-1"
    encrypt      = true
  }
}
