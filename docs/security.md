# Security

- AWS Verified Access is the sole public application entry point.
- IAM Identity Center authenticates users; Cedar policies require an approved email domain and group membership.
- The ALB is internal and application instances accept traffic only from the ALB security group.
- EC2 instances use IMDSv2, encrypted storage, private subnets, and SSM instead of SSH.
- Logs are retained in CloudWatch and S3 according to the Terraform configuration.
- Keep `terraform.tfvars`, CI variables, and state backends free of credentials and secrets.
