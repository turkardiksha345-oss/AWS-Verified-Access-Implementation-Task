variable "name_prefix" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "log_group_arns" {
  type = list(string)
}

variable "secrets_manager_arns" {
  type = list(string)
}

variable "s3_bucket_arns" {
  type = list(string)
}

variable "ecr_repository_arns" {
  type    = list(string)
  default = []
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN; created when enable_github_oidc is true"
  type        = string
  default     = ""
}

variable "github_url" {
  description = "GitHub base URL for OIDC"
  type        = string
  default     = "https://github.com"
}

variable "github_project_path" {
  description = "GitHub project path for OIDC subject condition"
  type        = string
  default     = "nehal-wandhare-group/secure-access-portal"
}

variable "enable_github_oidc" {
  description = "Create GitHub OIDC provider and allow CI/CD to assume the Terraform role"
  type        = bool
  default     = true
}

variable "tags" {
  type = map(string)
}

## OUTPUTS ##

output "ec2_instance_profile_arn" {
  value = aws_iam_instance_profile.ec2.arn
}

output "ec2_role_arn" {
  value = aws_iam_role.ec2.arn
}

output "terraform_role_arn" {
  value = aws_iam_role.terraform.arn
}

output "github_oidc_provider_arn" {
  value = local.github_oidc_provider_arn
}
