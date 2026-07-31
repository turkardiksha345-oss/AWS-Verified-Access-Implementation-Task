# Operations

Use IAM Identity Center and SSM Session Manager for administrative access; do not open SSH access to the instances.

```bash
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names secure-access-portal-dev-asg --region ap-south-1
aws logs tail /aws/application/secure-access-portal-dev --follow --region ap-south-1
```

To verify service access, authenticate through IAM Identity Center and open `https://portal-dev.cdec-engineer.store/health`.

Review CloudWatch alarms and Verified Access logs after every deployment.
