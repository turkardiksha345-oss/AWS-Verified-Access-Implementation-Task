# Troubleshooting

## Certificate pending validation

Confirm the ACM validation CNAME record exists in the `cdec-engineer.store` DNS zone. The application DNS record must wait until certificate validation completes.

## Access denied

Confirm the user is authenticated with IAM Identity Center, has an approved email domain, and belongs to an approved group. Review Verified Access logs in CloudWatch.

## Unhealthy application targets

Use SSM Session Manager to inspect the service:

```bash
sudo systemctl status secure-access-portal
sudo docker logs secure-access-portal
```

Confirm the ECR image tag exists and that `/health` returns HTTP 200.
