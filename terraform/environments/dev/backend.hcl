# Terraform state stored in S3 only (S3-native locking — no DynamoDB per platform team)
bucket       = "aws-access-verified-task"
key          = "verified-access/terraform.tfstate"
region       = "ap-southeast-2"
encrypt      = true
# Set this only after creating a KMS key in your AWS account.
# kms_key_id = "arn:aws:kms:ap-south-1:162521700916:key/<KEY_ID>"
use_lockfile = true
