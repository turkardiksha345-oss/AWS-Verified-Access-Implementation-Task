# Architecture

Secure Access Portal uses AWS Verified Access as the only client entry point. IAM Identity Center authenticates users, Cedar policies authorize approved identities, and an internal Application Load Balancer forwards permitted requests to EC2 instances in private subnets.

## Components

| Layer | Service | Purpose |
|---|---|---|
| DNS | External DNS | `portal-dev.cdec-engineer.store` CNAME to the Verified Access endpoint |
| Identity | IAM Identity Center | User authentication in `ap-south-1` |
| Authorization | Cedar | Approved email domain and group rules |
| Access | AWS Verified Access | Zero-trust application access |
| Compute | EC2 Auto Scaling Group | Private application servers |
| Observability | CloudWatch, S3, SNS | Logs, metrics, alarms, and audit records |

## Request flow

1. A user opens `https://portal-dev.cdec-engineer.store`.
2. Verified Access redirects unauthenticated users to IAM Identity Center.
3. Cedar evaluates the user email domain, group membership, and maintenance mode.
4. Permitted requests are forwarded to the internal ALB and application instances.
5. Denied requests are rejected and logged.
