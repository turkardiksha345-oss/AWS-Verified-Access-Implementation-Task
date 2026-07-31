#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting instance bootstrap at $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# System updates
dnf update -y
dnf install -y docker amazon-cloudwatch-agent jq

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Install and configure SSM Agent (pre-installed on AL2023, ensure running)
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Pull application image from ECR if configured
if [ -n "${ecr_repository_url}" ]; then
  # Terraform interpolates the full URL; then bash strips path for registry host.
  ECR_IMAGE_URI="${ecr_repository_url}"
  ECR_REGISTRY="$${ECR_IMAGE_URI%%/*}"
  aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin "$${ECR_REGISTRY}"
  docker pull "${ecr_repository_url}:${docker_image_tag}"
  IMAGE="${ecr_repository_url}:${docker_image_tag}"
else
  # Build from embedded application (development fallback)
  mkdir -p /opt/app
  cat > /opt/app/Dockerfile <<'DOCKERFILE'
FROM python:3.12-slim-bookworm
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
RUN useradd -r -s /sbin/nologin appuser
USER appuser
EXPOSE 8080
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--threads", "4", "--timeout", "30", "--graceful-timeout", "30", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
DOCKERFILE
  IMAGE="secure-access-portal:local"
fi

# Systemd service for the application container
cat > /etc/systemd/system/secure-access-portal.service <<SYSTEMD
[Unit]
Description=Secure Access Portal Application
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
Type=simple
Restart=always
RestartSec=5
TimeoutStopSec=30
ExecStartPre=-/usr/bin/docker stop secure-access-portal
ExecStartPre=-/usr/bin/docker rm secure-access-portal
ExecStart=/usr/bin/docker run --name secure-access-portal \\
  --rm \\
  -p ${app_port}:8080 \\
  -e APP_ENV=production \\
  -e LOG_LEVEL=INFO \\
  $${IMAGE}
ExecStop=/usr/bin/docker stop -t 25 secure-access-portal
KillMode=mixed

[Install]
WantedBy=multi-user.target
SYSTEMD

systemctl daemon-reload
systemctl enable secure-access-portal
systemctl start secure-access-portal

# CloudWatch Agent configuration
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<CWAGENT
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/user-data",
            "timezone": "UTC"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "SecureAccessPortal",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60,
        "totalcpu": false
      },
      "disk": {
        "measurement": ["used_percent", "inodes_free"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      }
    }
  }
}
CWAGENT

systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

echo "Bootstrap complete at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
