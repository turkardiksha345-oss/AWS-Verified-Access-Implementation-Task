# ---------------------------------------------------------------------------
# Verified Access Module — Zero Trust application access layer (VPC)
# Trust provider: IAM Identity Center (org-managed login; Cedar enforces access)
# ---------------------------------------------------------------------------

variable "name_prefix" {
  type = string
}

variable "fqdn" {
  type = string
}

variable "certificate_arn" {
  type = string
}

variable "load_balancer_arn" {
  type = string
}

variable "subnet_ids" {
  description = "Subnets for the Verified Access load-balancer endpoint (same AZs as ALB)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups for the Verified Access endpoint ENIs (required for VPC attachment)"
  type        = list(string)
}

variable "identity_center_instance_arn" {
  description = "Optional org Identity Center ARN (informational; trust provider auto-binds to org IdC)"
  type        = string
  default     = ""
}

variable "cedar_group_policy" {
  type = string
}

variable "cedar_endpoint_policy" {
  type = string
}

variable "cedar_policy_version" {
  type = string
}

variable "log_group_name" {
  description = "CloudWatch Logs group name for Verified Access access logs (name only, not ARN)"
  type        = string
}

variable "tags" {
  type = map(string)
}

resource "aws_verifiedaccess_instance" "main" {
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-va-instance"
  })
}

resource "aws_verifiedaccess_trust_provider" "identity_center" {
  policy_reference_name    = "${replace(var.name_prefix, "-", "")}IdC"
  trust_provider_type      = "user"
  user_trust_provider_type = "iam-identity-center"
  description              = "IAM Identity Center trust provider for ${var.fqdn}"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-va-trust-idc"
  })
}

resource "aws_verifiedaccess_instance_trust_provider_attachment" "idc" {
  verifiedaccess_instance_id       = aws_verifiedaccess_instance.main.id
  verifiedaccess_trust_provider_id = aws_verifiedaccess_trust_provider.identity_center.id
}

resource "aws_verifiedaccess_group" "main" {
  verifiedaccess_instance_id = aws_verifiedaccess_instance.main.id
  policy_document            = var.cedar_group_policy

  tags = merge(var.tags, {
    Name          = "${var.name_prefix}-va-group"
    PolicyVersion = var.cedar_policy_version
  })

  depends_on = [
    aws_verifiedaccess_instance_trust_provider_attachment.idc
  ]
}

resource "aws_verifiedaccess_endpoint" "main" {
  application_domain       = var.fqdn
  attachment_type          = "vpc"
  description              = "Verified Access endpoint for ${var.fqdn}"
  domain_certificate_arn   = var.certificate_arn
  endpoint_domain_prefix   = substr(replace(var.name_prefix, "_", "-"), 0, 20)
  endpoint_type            = "load-balancer"
  policy_document          = var.cedar_endpoint_policy
  security_group_ids       = var.security_group_ids
  verified_access_group_id = aws_verifiedaccess_group.main.id

  load_balancer_options {
    load_balancer_arn = var.load_balancer_arn
    port              = 443
    protocol          = "https"
    subnet_ids        = var.subnet_ids
  }

  sse_specification {
    customer_managed_key_enabled = false
  }

  tags = merge(var.tags, {
    Name          = "${var.name_prefix}-va-endpoint"
    PolicyVersion = var.cedar_policy_version
  })
}

resource "aws_verifiedaccess_instance_logging_configuration" "main" {
  verifiedaccess_instance_id = aws_verifiedaccess_instance.main.id

  access_logs {
    cloudwatch_logs {
      enabled   = true
      log_group = var.log_group_name
    }

    include_trust_context = true
  }
}

output "instance_id" {
  value = aws_verifiedaccess_instance.main.id
}

output "endpoint_id" {
  value = aws_verifiedaccess_endpoint.main.id
}

output "endpoint_domain_name" {
  value = aws_verifiedaccess_endpoint.main.endpoint_domain
}

output "trust_provider_id" {
  value = aws_verifiedaccess_trust_provider.identity_center.id
}

output "group_id" {
  value = aws_verifiedaccess_group.main.id
}
