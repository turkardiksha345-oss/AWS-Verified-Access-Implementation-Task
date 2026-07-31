# Rollback

1. Identify the previous working application image tag.
2. Set `docker_image_tag` to that tag in the environment configuration.
3. Run `terraform plan` and review the change.
4. Run `terraform apply` to start the Auto Scaling Group instance refresh.
5. Confirm `/health` is healthy through the Verified Access URL.

Terraform state is versioned in your own S3 backend. Restore an older state version only after reviewing the exact resources that would change.
