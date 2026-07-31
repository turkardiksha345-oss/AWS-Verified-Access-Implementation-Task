# ---------------------------------------------------------------------------
# IAM Identity Center Module — users, groups, and Verified Access integration
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

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

data "aws_ssoadmin_instances" "main" {}

locals {
  identity_center_instance_arn = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  identity_store_id            = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]

  memberships = flatten([
    for username, user in var.users : [
      for group in user.groups : {
        key      = "${username}-${group}"
        username = username
        group    = group
      }
    ]
  ])
}

resource "aws_identitystore_group" "approved" {
  for_each = toset(var.approved_groups)

  identity_store_id = local.identity_store_id
  display_name      = each.value
  description       = "Verified Access approved group: ${each.value}"
}

# Users — managed via identity_center_users in terraform.tfvars
resource "aws_identitystore_user" "users" {
  for_each = var.users

  identity_store_id = local.identity_store_id
  display_name      = "${each.value.given_name} ${each.value.family_name}"
  user_name         = each.key

  name {
    given_name  = each.value.given_name
    family_name = each.value.family_name
  }

  emails {
    value   = each.value.email
    primary = true
    type    = "work"
  }
}

resource "aws_identitystore_group_membership" "users" {
  for_each = { for membership in local.memberships : membership.key => membership }

  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.approved[each.value.group].group_id
  member_id         = aws_identitystore_user.users[each.value.username].user_id
}

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
