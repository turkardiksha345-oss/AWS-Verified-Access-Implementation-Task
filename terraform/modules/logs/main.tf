# ---------------------------------------------------------------------------
# Logs Module — centralized logging, CloudTrail, AWS Config, GuardDuty
# ---------------------------------------------------------------------------

variable "name_prefix" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "log_retention_days" {
  type = number
}

variable "kms_key_arn" {
  type    = string
  default = null
}

variable "cloudtrail_bucket" {
  type    = string
  default = ""
}

variable "enable_config" {
  type = bool
}

variable "enable_cloudtrail" {
  description = "Create CloudTrail trail and related IAM/log group (often blocked on sandbox SSO)"
  type        = bool
  default     = false
}

variable "tags" {
  type = map(string)
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  # Regional ELB account IDs for classic ALB access-log delivery principals.
  # See: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html
  elb_account_ids = {
    "us-east-1"      = "127311923021"
    "us-east-2"      = "033677994240"
    "us-west-1"      = "027434742980"
    "us-west-2"      = "797873946194"
    "ap-south-1"     = "718504428378"
    "ap-northeast-1" = "582318560864"
    "ap-northeast-2" = "600734575887"
    "ap-southeast-1" = "114774131450"
    "ap-southeast-2" = "783225319266"
    "eu-central-1"   = "054676820928"
    "eu-west-1"      = "156460612806"
    "eu-west-2"      = "652711504416"
    "ca-central-1"   = "985666609251"
  }
  elb_account_id = lookup(local.elb_account_ids, var.aws_region, null)
}

# Create the Auto Scaling service-linked role before referencing it in the KMS
# policy. KMS rejects policies that name a role which does not yet exist.
# resource "aws_iam_service_linked_role" "autoscaling" {
# aws_service_name = "my-autoscaling.amazonaws.com"
 # description      = "Service-linked role for Secure Access Portal Auto Scaling"
# }

# KMS key for encryption at rest (created if not provided)
resource "aws_kms_key" "logs" {
  count = var.kms_key_arn == null ? 1 : 0

  description             = "${var.name_prefix} logs encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${local.partition}:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:${local.partition}:logs:${var.aws_region}:${local.account_id}:*"
          }
        }
      },
      {
        Sid    = "AllowCloudTrail"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt",
          "kms:DescribeKey",
        ]
        Resource = "*"
      },
      # Required for ASG to launch EC2 with CMK-encrypted EBS volumes
      {
        Sid    = "AllowAutoScalingServiceLinkedRole"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_service_linked_role.autoscaling.arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowAutoScalingCreateGrant"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_service_linked_role.autoscaling.arn
        }
        Action   = "kms:CreateGrant"
        Resource = "*"
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" = "true"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-logs-kms"
  })
}

locals {
  kms_arn = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.logs[0].arn
}

# CloudWatch Log Groups (AWS-managed encryption — avoids sandbox KMS policy issues)
resource "aws_cloudwatch_log_group" "verified_access" {
  name              = "/aws/verifiedaccess/${var.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-va-logs"
  })
}

resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/application/${var.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-app-logs"
  })
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  name              = "/aws/cloudtrail/${var.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cloudtrail-logs"
  })
}

resource "aws_s3_bucket" "alb_logs" {
  bucket = lower("${var.name_prefix}-alb-logs-${local.account_id}")

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-logs"
  })
}

# ALB access logs only support SSE-S3 (AES256), not CMK/SSE-KMS.
resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter {
      prefix = "alb/"
    }

    expiration {
      days = var.log_retention_days
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      local.elb_account_id != null ? [
        {
          Sid    = "AllowELBAccountPut"
          Effect = "Allow"
          Principal = {
            AWS = "arn:${local.partition}:iam::${local.elb_account_id}:root"
          }
          Action   = "s3:PutObject"
          Resource = "${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${local.account_id}/*"
        }
      ] : [],
      [
        {
          Sid    = "AllowELBLogDeliveryServicePut"
          Effect = "Allow"
          Principal = {
            Service = "logdelivery.elasticloadbalancing.amazonaws.com"
          }
          Action   = "s3:PutObject"
          Resource = "${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${local.account_id}/*"
        },
        {
          Sid    = "AWSLogDeliveryWrite"
          Effect = "Allow"
          Principal = {
            Service = "delivery.logs.amazonaws.com"
          }
          Action   = "s3:PutObject"
          Resource = "${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${local.account_id}/*"
          Condition = {
            StringEquals = {
              "s3:x-amz-acl"      = "bucket-owner-full-control"
              "aws:SourceAccount" = local.account_id
            }
          }
        },
        {
          Sid    = "AWSLogDeliveryAclCheck"
          Effect = "Allow"
          Principal = {
            Service = "delivery.logs.amazonaws.com"
          }
          Action   = "s3:GetBucketAcl"
          Resource = aws_s3_bucket.alb_logs.arn
          Condition = {
            StringEquals = {
              "aws:SourceAccount" = local.account_id
            }
          }
        }
      ]
    )
  })
}

resource "aws_s3_bucket" "flow_logs" {
  bucket = var.cloudtrail_bucket != "" ? var.cloudtrail_bucket : lower("${var.name_prefix}-cloudtrail-${local.account_id}")

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-flow-logs"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = local.kms_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "cloudtrail" {
  count = var.enable_cloudtrail || var.enable_config ? 1 : 0

  bucket = var.cloudtrail_bucket != "" ? var.cloudtrail_bucket : "${var.name_prefix}-cloudtrail-${local.account_id}"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cloudtrail"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  count  = var.enable_cloudtrail || var.enable_config ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = local.kms_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  count  = var.enable_cloudtrail || var.enable_config ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  count  = var.enable_cloudtrail || var.enable_config ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail[0].arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail[0].arn}/AWSLogs/${local.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# CloudTrail — optional for sandbox SSO
resource "aws_cloudtrail" "main" {
  count = var.enable_cloudtrail ? 1 : 0

  name                          = "${var.name_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail[0].id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = local.kms_arn

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail[0].arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cloudtrail"
  })

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

resource "aws_iam_role" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  name = "${var.name_prefix}-cloudtrail-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  name = "${var.name_prefix}-cloudtrail-logs"
  role = aws_iam_role.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
    }]
  })
}

# AWS Config
resource "aws_iam_role" "config" {
  count = var.enable_config ? 1 : 0

  name = "${var.name_prefix}-config"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "config.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "config" {
  count = var.enable_config ? 1 : 0

  role       = aws_iam_role.config[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "main" {
  count = var.enable_config ? 1 : 0

  name     = "${var.name_prefix}-config"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  count = var.enable_config ? 1 : 0

  name           = "${var.name_prefix}-config"
  s3_bucket_name = aws_s3_bucket.cloudtrail[0].id

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  count = var.enable_config ? 1 : 0

  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

# Secrets Manager — application secrets placeholder
resource "aws_secretsmanager_secret" "app" {
  name                    = "${var.name_prefix}/app/config"
  description             = "Application configuration secrets"
  kms_key_id              = local.kms_arn
  recovery_window_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-app-secrets"
  })
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  secret_string = jsonencode({
    app_env   = "production"
    log_level = "INFO"
  })
}

output "verified_access_log_group_arn" {
  value = aws_cloudwatch_log_group.verified_access.arn
}

output "verified_access_log_group_name" {
  value = aws_cloudwatch_log_group.verified_access.name
}

output "application_log_group_name" {
  value = aws_cloudwatch_log_group.application.name
}

output "log_group_arns" {
  value = compact([
    aws_cloudwatch_log_group.verified_access.arn,
    aws_cloudwatch_log_group.application.arn,
    try(aws_cloudwatch_log_group.cloudtrail[0].arn, null),
  ])
}

output "secrets_manager_arns" {
  value = [aws_secretsmanager_secret.app.arn]
}

output "alb_logs_bucket_arn" {
  value = aws_s3_bucket.alb_logs.arn
}

output "alb_logs_bucket_name" {
  value = aws_s3_bucket.alb_logs.bucket
}

output "flow_logs_bucket_arn" {
  value = aws_s3_bucket.flow_logs.arn
}

output "cloudtrail_arn" {
  value = try(aws_cloudtrail.main[0].arn, null)
}

output "kms_key_arn" {
  value = local.kms_arn
}
