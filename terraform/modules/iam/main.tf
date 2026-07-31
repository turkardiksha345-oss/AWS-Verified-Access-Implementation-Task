# ---------------------------------------------------------------------------
# IAM Module — least-privilege roles for EC2, Terraform, and service principals
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.no_default_tags]
    }
  }
}

variable "name_prefix" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "log_group_arns" {
  type = list(string)
}

variable "secrets_manager_arns" {
  type = list(string)
}

variable "s3_bucket_arns" {
  type = list(string)
}

variable "ecr_repository_arns" {
  type    = list(string)
  default = []
}

variable "gitlab_oidc_provider_arn" {
  description = "Existing GitLab OIDC provider ARN; created when enable_gitlab_oidc is true"
  type        = string
  default     = ""
}

variable "gitlab_url" {
  description = "GitLab base URL for OIDC"
  type        = string
  default     = "https://gitlab.com"
}

variable "gitlab_project_path" {
  description = "GitLab project path for OIDC subject condition"
  type        = string
  default     = "nehal-wandhare-group/secure-access-portal"
}

variable "enable_gitlab_oidc" {
  description = "Create GitLab OIDC provider and allow CI/CD to assume the Terraform role"
  type        = bool
  default     = true
}

variable "tags" {
  type = map(string)
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# Fetch GitLab TLS thumbprint for IAM OIDC provider
data "tls_certificate" "gitlab" {
  count = var.enable_gitlab_oidc && var.gitlab_oidc_provider_arn == "" ? 1 : 0
  url   = var.gitlab_url
}

locals {
  gitlab_oidc_host = replace(replace(var.gitlab_url, "https://", ""), "http://", "")

  gitlab_oidc_provider_arn = var.enable_gitlab_oidc ? (
    length(aws_iam_openid_connect_provider.gitlab) > 0 ? aws_iam_openid_connect_provider.gitlab[0].arn : var.gitlab_oidc_provider_arn
  ) : var.gitlab_oidc_provider_arn

  gitlab_oidc_thumbprints = length(data.tls_certificate.gitlab) > 0 ? distinct([
    for cert in data.tls_certificate.gitlab[0].certificates : cert.sha1_fingerprint
  ]) : []

  terraform_assume_role_statements = concat(
    [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "${var.name_prefix}-terraform"
          }
        }
      }
    ],
    local.gitlab_oidc_provider_arn != "" ? [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.gitlab_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.gitlab_oidc_host}:aud" = var.gitlab_url
          }
          StringLike = {
            "${local.gitlab_oidc_host}:sub" = "project_path:${var.gitlab_project_path}:*"
          }
        }
      }
    ] : []
  )
}

resource "aws_iam_openid_connect_provider" "gitlab" {
  count = var.enable_gitlab_oidc && var.gitlab_oidc_provider_arn == "" ? 1 : 0

  url = var.gitlab_url

  client_id_list = [
    var.gitlab_url,
  ]

  thumbprint_list = local.gitlab_oidc_thumbprints

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-gitlab-oidc"
  })
}

resource "aws_iam_role" "ec2" {
  name = "${var.name_prefix}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "ec2_ssm" {
  name = "${var.name_prefix}-ec2-ssm"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SSMSessionManager"
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "ec2messages:AcknowledgeMessage",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = var.log_group_arns
      },
      {
        Sid    = "CloudWatchAgent"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "SecureAccessPortal"
          }
        }
      },
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.secrets_manager_arns
      },
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRPullRepository"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = var.ecr_repository_arns
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_managed" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_agent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Use no_default_tags provider — default_tags force TagInstanceProfile (denied on sandbox SSO).
resource "aws_iam_instance_profile" "ec2" {
  provider = aws.no_default_tags

  name = "${var.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_iam_role" "terraform" {
  name = "${var.name_prefix}-terraform-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.terraform_assume_role_statements
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "terraform" {
  name = "${var.name_prefix}-terraform-policy"
  role = aws_iam_role.terraform.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformState"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:s3:::secure-access-portal-terraform-state-*",
          "arn:${data.aws_partition.current.partition}:s3:::secure-access-portal-terraform-state-*/*"
        ]
      },
      {
        Sid    = "TerraformLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/secure-access-portal-terraform-locks-*"
      },
      {
        Sid      = "DeployProjectResources"
        Effect   = "Allow"
        Action   = ["*"]
        Resource = "*"
      },
      {
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Sid    = "IdentityCenter"
        Effect = "Allow"
        Action = [
          "sso:*",
          "identitystore:*",
          "sso-admin:*"
        ]
        Resource = "*"
      }
    ]
  })
}

output "ec2_instance_profile_arn" {
  value = aws_iam_instance_profile.ec2.arn
}

output "ec2_role_arn" {
  value = aws_iam_role.ec2.arn
}

output "terraform_role_arn" {
  value = aws_iam_role.terraform.arn
}

output "gitlab_oidc_provider_arn" {
  value = local.gitlab_oidc_provider_arn
}
