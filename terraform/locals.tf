locals {
  name_prefix = "${var.project_name}-${var.environment}"
  fqdn        = "${var.app_subdomain}.${var.domain_name}"

  identity_center_instance_arn = try(module.identity_center[0].instance_arn, var.identity_center_instance_arn)

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
    Compliance  = "CIS-AWS-Benchmark"
  }

  # Cedar policies are rendered from template files with variable substitution
  cedar_group_policy = templatefile("${path.module}/../cedar/group-policy.cedar", {
    approved_email_domain = var.approved_email_domain
    approved_groups       = jsonencode(var.approved_groups)
    maintenance_mode      = var.maintenance_mode
    policy_version        = var.cedar_policy_version
  })

  cedar_endpoint_policy = templatefile("${path.module}/../cedar/endpoint-policy.cedar", {
    approved_email_domain = var.approved_email_domain
    approved_groups       = jsonencode(var.approved_groups)
    maintenance_mode      = var.maintenance_mode
    policy_version        = var.cedar_policy_version
  })
}
