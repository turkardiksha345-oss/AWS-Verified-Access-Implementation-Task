output "vpc_id" {
  description = "VPC identifier"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "ALB DNS name (internal — access via Verified Access endpoint)"
  value       = module.alb.alb_dns_name
}

output "target_group_arn" {
  description = "ALB target group ARN"
  value       = module.alb.target_group_arn
}

output "ecr_repository_url" {
  description = "ECR repository URL for the application image"
  value       = var.create_ecr_repository ? module.ecr[0].repository_url : var.ecr_repository_url
}

output "terraform_role_arn_output" {
  description = "Terraform deployment role ARN for GitLab CI AWS_ROLE_ARN variable"
  value       = module.iam.terraform_role_arn
}

output "verified_access_endpoint_dns" {
  description = "Verified Access endpoint DNS — point CNAME here"
  value       = module.verified_access.endpoint_domain_name
}

output "application_url" {
  description = "Public application URL (Verified Access protected)"
  value       = "https://${local.fqdn}"
}

output "acm_validation_records" {
  description = "DNS records required for ACM certificate validation — send to your DNS team first"
  value       = module.acm.validation_records
}

output "dns_records_for_manager" {
  description = "DNS records to send to your DNS manager for the application domain"
  value = concat(
    [for r in module.acm.validation_records : {
      name    = r.name
      type    = r.type
      value   = r.value
      purpose = "ACM TLS certificate validation (add this first)"
    }],
    [{
      name    = local.fqdn
      type    = "CNAME"
      value   = module.verified_access.endpoint_domain_name
      purpose = "Application URL — CNAME to Verified Access endpoint (not ALB)"
    }]
  )
}

output "verified_access_instance_id" {
  description = "Verified Access instance ID"
  value       = module.verified_access.instance_id
}

output "verified_access_endpoint_id" {
  description = "Verified Access endpoint ID"
  value       = module.verified_access.endpoint_id
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.monitoring.dashboard_url
}

output "sns_topic_arn" {
  description = "SNS topic ARN for operational alarms"
  value       = module.sns.topic_arn
}

output "cedar_policy_version" {
  description = "Currently deployed Cedar policy version"
  value       = var.cedar_policy_version
}

output "identity_center_groups" {
  description = "IAM Identity Center groups configured for access"
  value       = var.manage_identity_center ? module.identity_center[0].group_names : var.approved_groups
  sensitive   = true
}

output "identity_center_managed_by_terraform" {
  description = "Whether Identity Center users/groups are managed by Terraform"
  value       = var.manage_identity_center
}

output "ec2_instance_ids" {
  description = "EC2 instance IDs (access via SSM Session Manager only)"
  value       = module.ec2.instance_ids
}

output "cloudtrail_arn" {
  description = "CloudTrail trail ARN (null when enable_cloudtrail is false)"
  value       = module.logs.cloudtrail_arn
}
