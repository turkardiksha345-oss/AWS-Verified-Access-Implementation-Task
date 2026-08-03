variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for internal ALB (no public exposure)"
  type        = list(string)
}

variable "security_group_id" {
  type = string
}

variable "certificate_arn" {
  type = string
}

variable "app_port" {
  type = number
}

variable "enable_deletion_protection" {
  type = bool
}

variable "enable_waf" {
  type    = bool
  default = false
}

variable "alb_logs_bucket" {
  type = string
}

variable "tags" {
  type = map(string)
}

## OUTPUTS ##

output "alb_arn" {
  value = aws_lb.main.arn
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "alb_zone_id" {
  value = aws_lb.main.zone_id
}

output "alb_arn_suffix" {
  value = aws_lb.main.arn_suffix
}

output "target_group_arn" {
  value = aws_lb_target_group.app.arn
}

output "target_group_arn_suffix" {
  value = aws_lb_target_group.app.arn_suffix
}
