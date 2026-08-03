# Terraform state stored in S3 only (S3-native locking — no DynamoDB per platform team)
bucket       = "secure-access-portal-terraform-state-162521700916"
key          = "verified-access/terraform.tfstate"
region       = "eu-north-1"
encrypt      = true
# Set this only after creating a KMS key in your AWS account.
# kms_key_id = "arn:aws:kms:ap-south-1:162521700916:key/<KEY_ID>"
use_lockfile = true
