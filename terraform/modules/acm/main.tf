# ---------------------------------------------------------------------------
# ACM Module — TLS certificate with external DNS validation
# ---------------------------------------------------------------------------

variable "name_prefix" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "tags" {
  type = map(string)
}

resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  options {
    certificate_transparency_logging_preference = "ENABLED"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cert"
  })
}

locals {
  validation_options = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
      fqdn   = dvo.resource_record_name
    }
  }

  validation_fqdns = [for option in local.validation_options : option.fqdn]
}

# Waits until validation CNAME is added in external DNS.
# Keep timeout finite so SSO tokens don't silently expire for hours.
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = local.validation_fqdns

  timeouts {
    create = "30m"
  }
}

output "certificate_arn" {
  value = aws_acm_certificate_validation.main.certificate_arn
}

output "validation_records" {
  description = "CNAME records for ACM TLS validation — send to your DNS manager"
  value = [
    for option in local.validation_options : {
      name  = option.name
      type  = option.type
      value = option.record
    }
  ]
}
