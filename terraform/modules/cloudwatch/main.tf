# ---------------------------------------------------------------------------
# CloudWatch Module — supplementary log metric filters
# ---------------------------------------------------------------------------



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

