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


data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# Fetch GitHub TLS thumbprint for IAM OIDC provider
data "tls_certificate" "github" {
  count = var.enable_github_oidc && var.github_oidc_provider_arn == "" ? 1 : 0
  url   = var.github_url
}

locals {
  github_oidc_host = replace(replace(var.github_url, "https://", ""), "http://", "")

  github_oidc_provider_arn = var.enable_github_oidc ? (
    length(aws_iam_openid_connect_provider.github) > 0 ? aws_iam_openid_connect_provider.github[0].arn : var.github_oidc_provider_arn
  ) : var.github_oidc_provider_arn

  github_oidc_thumbprints = length(data.tls_certificate.github) > 0 ? distinct([
    for cert in data.tls_certificate.github[0].certificates : cert.sha1_fingerprint
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
    local.github_oidc_provider_arn != "" ? [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.github_oidc_host}:aud" = var.github_url
          }
          StringLike = {
            "${local.github_oidc_host}:sub" = "project_path:${var.github_project_path}:*"
          }
        }
      }
    ] : []
  )
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.enable_github_oidc && var.github_oidc_provider_arn == "" ? 1 : 0

  url = var.github_url

  client_id_list = [
    var.github_url,
  ]

  thumbprint_list = local.github_oidc_thumbprints

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-github-oidc"
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

