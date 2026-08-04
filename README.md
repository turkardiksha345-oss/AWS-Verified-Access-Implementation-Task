# Secure Access Portal

Secure application access using AWS Verified Access, IAM Identity Center, Cedar policies, and Terraform.

## Architecture

`portal-dev.cdec-engineer.store` -> Verified Access -> internal ALB -> private EC2 Auto Scaling Group -> Flask application.

## Prerequisites

- An AWS account with IAM Identity Center enabled in `ap-south-1`
- Terraform >= 1.10
- Docker
- GitLab CI/CD with OIDC to AWS
- Control of the `cdec-engineer.store` DNS zone

## Deploy

```bash
cd terraform
terraform init -backend-config=environments/dev/backend.hcl
terraform plan -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
```

Before applying, replace `<YOUR_AWS_ACCOUNT_ID>` in the backend and environment configuration with your AWS account ID. Create the remote-state bucket and deployment role first.

## Run locally

```bash
cd application
pip install -r requirements.txt -r requirements-dev.txt
python -m pytest tests/ -v
python app.py
```

## Github CI/CD

Repository: `turkardiksha345-oss/AWS-Verified-Access-Implementation-Task`

Set `AWS_ROLE_ARN` to the deployted `secure-access-portal-terraform-role` ARN in Github CI/CD variables.

## DNS

After the ACM certificate validation record is created, point `app.cdec-engineer.store` to the Verified Access endpoint shown by:

```bash
terraform output -json dns_records_for_manager
```

## Documentation

- [Architecture](docs/architecture.md)
- [Deployment](docs/deployment.md)
- [Operations](docs/operations.md)
- [Security](docs/security.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Rollback](docs/rollback.md)
