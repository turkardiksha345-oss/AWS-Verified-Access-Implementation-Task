provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }

  dynamic "assume_role" {
    for_each = var.terraform_assume_role_enabled ? [1] : []
    content {
      role_arn     = var.terraform_role_arn
      session_name = "terraform-verified-access"
      external_id  = "${var.project_name}-${var.environment}-terraform"
    }
  }
}

# Sandbox SSO often allows CreateInstanceProfile but denies TagInstanceProfile.
# Use this alias for IAM instance profiles so provider default_tags are not applied.
provider "aws" {
  alias  = "no_default_tags"
  region = var.aws_region

  dynamic "assume_role" {
    for_each = var.terraform_assume_role_enabled ? [1] : []
    content {
      role_arn     = var.terraform_role_arn
      session_name = "terraform-verified-access-no-tags"
      external_id  = "${var.project_name}-${var.environment}-terraform"
    }
  }
}

# Identity Center is managed in the configured organization home region.
provider "aws" {
  alias  = "identity_center"
  region = var.identity_center_region

  default_tags {
    tags = local.common_tags
  }

  dynamic "assume_role" {
    for_each = var.terraform_assume_role_enabled ? [1] : []
    content {
      role_arn     = var.terraform_role_arn
      session_name = "terraform-identity-center"
      external_id  = "${var.project_name}-${var.environment}-terraform"
    }
  }
}
