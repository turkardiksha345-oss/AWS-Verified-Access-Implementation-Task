# ---------------------------------------------------------------------------
# CloudWatch Module — supplementary log metric filters
# ---------------------------------------------------------------------------

variable "name_prefix" {
  type = string
}

variable "log_retention_days" {
  type = number
}

variable "verified_access_log_group_name" {
  type = string
}

variable "application_log_group_name" {
  type = string
}

variable "alb_arn_suffix" {
  type = string
}

variable "target_group_arn_suffix" {
  type = string
}

variable "kms_key_arn" {
  type    = string
  default = null
}

variable "tags" {
  type = map(string)
}

# Metric filter: Verified Access denied requests
resource "aws_cloudwatch_log_metric_filter" "va_denied" {
  name           = "${var.name_prefix}-va-denied"
  pattern        = "{ $.action = \"access-denied\" }"
  log_group_name = var.verified_access_log_group_name

  metric_transformation {
    name      = "VerifiedAccessDenied"
    namespace = "SecureAccessPortal"
    value     = "1"
    unit      = "Count"
  }
}

# Metric filter: Application errors
resource "aws_cloudwatch_log_metric_filter" "app_errors" {
  name           = "${var.name_prefix}-app-errors"
  pattern        = "{ $.level = \"ERROR\" || $.level = \"CRITICAL\" }"
  log_group_name = var.application_log_group_name

  metric_transformation {
    name      = "ApplicationErrors"
    namespace = "SecureAccessPortal"
    value     = "1"
    unit      = "Count"
  }
}

output "va_denied_metric_name" {
  value = "VerifiedAccessDenied"
}

output "app_errors_metric_name" {
  value = "ApplicationErrors"
}
