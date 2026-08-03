variable "name_prefix" {
  type = string
}

variable "approved_groups" {
  type = list(string)
}

variable "approved_domain" {
  type = string
}


variable "users" {
  description = "IAM Identity Center users and their group memberships"
  type = map(object({
    given_name  = string
    family_name = string
    email       = string
    groups      = list(string)
  }))
}

variable "tags" {
  type = map(string)
}

## OUTPUTS ##

output "instance_arn" {
  value = local.identity_center_instance_arn
}

output "identity_store_id" {
  value = local.identity_store_id
}

output "group_names" {
  value = var.approved_groups
}

output "group_ids" {
  value = { for k, v in aws_identitystore_group.approved : k => v.group_id }
}

output "user_emails" {
  value = { for k, v in aws_identitystore_user.users : k => v.user_id }
}
