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

## OUTPUTS ##

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
