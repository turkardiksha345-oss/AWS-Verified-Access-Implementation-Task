# Deployment

1. Sign in to your AWS account and set the AWS CLI region to `ap-south-1`.
2. Create a private S3 bucket named `secure-access-portal-terraform-state-<ACCOUNT_ID>` and enable versioning.
3. Replace `<YOUR_AWS_ACCOUNT_ID>` in `terraform/environments/dev/backend.hcl` and `terraform/environments/dev/terraform.tfvars`.
4. Create the deployment role named `secure-access-portal-dev-terraform-role` or perform the initial apply with `terraform_assume_role_enabled=false`.
5. Create the certificate first so you can add its external DNS validation record:

```bash
cd terraform
terraform init -backend-config=environments/dev/backend.hcl
terraform apply -target=module.acm.aws_acm_certificate.main -var-file=environments/dev/terraform.tfvars -var="terraform_assume_role_enabled=false"
```

6. Add the ACM validation CNAME record displayed for the certificate in the AWS Certificate Manager console.
7. After certificate validation succeeds, run the full Terraform plan and apply with `terraform_assume_role_enabled=false`.
8. Add the application CNAME for `portal-dev.cdec-engineer.store` using `terraform output -json dns_records_for_manager`.
9. Build and push the application image to the created ECR repository, then update `docker_image_tag` and apply again.

Do not store AWS credentials, access keys, or account IDs in GitLab variables visible to untrusted pipelines.
