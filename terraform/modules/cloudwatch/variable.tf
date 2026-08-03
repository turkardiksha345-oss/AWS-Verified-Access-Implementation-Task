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

## OUTPUTS ##

output "va_denied_metric_name" {
  value = "VerifiedAccessDenied"
}

output "app_errors_metric_name" {
  value = "ApplicationErrors"
}
