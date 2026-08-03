# ---------------------------------------------------------------------------
# Global variables — overridden per environment via tfvars
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "Primary AWS region for workload resources"
  type        = string
  default     = "eu-north-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS region identifier."
  }
}

variable "identity_center_region" {
  description = "Region where IAM Identity Center is configured"
  type        = string
  default     = "eu-north-1"
}

variable "manage_identity_center" {
  description = <<-EOT
    Create Identity Center groups/users via Terraform.
    Set false when SSO lacks identitystore/sso APIs (org IC is management-account owned).
    Verified Access still uses IAM Identity Center as trust provider; platform admin manages groups/users.
  EOT
  type        = bool
  default     = false
}

variable "identity_center_instance_arn" {
  description = <<-EOT
    Optional IAM Identity Center instance ARN (arn:aws:sso:::instance/ssoins-...).
    Not required when manage_identity_center is false — the VA trust provider type
    iam-identity-center attaches to the org Identity Center automatically.
    Set this if your admin shares the ARN for documentation/validation.
  EOT
  type        = string
  default     = ""
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "Preprod"

  validation {
    condition     = var.environment == "Preprod"
    error_message = "Only the Preprod environment is supported."
  }
}

variable "project_name" {
  description = "Short project identifier used in resource naming"
  type        = string
  default     = "secure-access-portal"
}

variable "domain_name" {
  description = "Public DNS domain for the application"
  type        = string
  default     = "cdec-engineer.store"
}

variable "app_subdomain" {
  description = "Subdomain for the Verified Access protected application"
  type        = string
  default     = "app"
}

variable "terraform_role_arn" {
  description = "IAM role ARN assumed by Terraform in CI/CD"
  type        = string
  default     = ""
}

variable "terraform_assume_role_enabled" {
  description = "Assume terraform_role_arn in the AWS provider; set false on first local apply (role does not exist yet) or when CI uses OIDC directly"
  type        = bool
  default     = false
}

variable "owner" {
  description = "Team or individual responsible for this infrastructure"
  type        = string
  default     = "diksha-turkar"
}

variable "cost_center" {
  description = "Cost allocation tag"
  type        = string
  default     = "personal"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs to spread resources across"
  type        = list(string)
  default     = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "ec2_instance_type" {
  description = "EC2 instance type for application servers"
  type        = string
  default     = "t3.micro"
}

variable "ec2_min_size" {
  description = "Minimum number of EC2 instances"
  type        = number
  default     = 2
}

variable "ec2_max_size" {
  description = "Maximum number of EC2 instances"
  type        = number
  default     = 4
}

variable "ec2_desired_capacity" {
  description = "Desired number of EC2 instances"
  type        = number
  default     = 2
}

variable "app_port" {
  description = "Port the Flask application listens on"
  type        = number
  default     = 8080
}

variable "approved_email_domain" {
  description = "Email domain suffix allowed by Cedar policy"
  type        = string
  default     = "cdec-engineer.store"
}

variable "approved_groups" {
  description = "IAM Identity Center groups permitted to access the application"
  type        = list(string)
  default     = ["VerifiedAccessUsers", "DevOps", "Admins"]
}

variable "identity_center_users" {
  description = <<-EOT
    IAM Identity Center users for Verified Access authentication.
    Add users in environments/dev/terraform.tfvars with @approved_email_domain email
    and membership in an approved group.
    EOT
  type = map(object({
    given_name  = string
    family_name = string
    email       = string
    groups      = list(string)
  }))
  default = {
    "admin-user" = {
      given_name  = "Admin"
      family_name = "User"
      email       = "admin@cdec-engineer.store"
      groups      = ["Admins"]
    }
    "devops-user" = {
      given_name  = "DevOps"
      family_name = "User"
      email       = "devops@cdec-engineer.store"
      groups      = ["DevOps"]
    }
    "va-user" = {
      given_name  = "VA"
      family_name = "User"
      email       = "access-user@cdec-engineer.store"
      groups      = ["VerifiedAccessUsers"]
    }
    "denied-user" = {
      given_name  = "Denied"
      family_name = "User"
      email       = "denied-user@example.net"
      groups      = []
    }
  }
}

variable "create_ecr_repository" {
  description = "Create an ECR repository for the application Docker image"
  type        = bool
  default     = true
}

variable "github_project_path" {
  description = "GitHub project path for OIDC federation"
  type        = string
  default     = "turkardiksha345-oss/AWS-Verified-Access-Implementation-Task"
  }

variable "github_url" {
  description = "GitHub base URL used for OIDC federation"
  type        = string
  default     = "https://github.com"
}

variable "enable_github_oidc" {
  description = "Create GitHub OIDC provider and allow CI/CD to assume the Terraform role"
  type        = bool
  default     = true
}

variable "maintenance_mode" {
  description = "When true, only Admins group may access (Cedar policy)"
  type        = bool
  default     = false
}

variable "cedar_policy_version" {
  description = "Version tag for Cedar policy rollback tracking"
  type        = string
  default     = "v1.0.0"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 90

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch retention value."
  }
}

variable "alarm_email" {
  description = "Email address for SNS alarm notifications"
  type        = string
  default     = "dikshaturkar2022@gmail.com"
}

variable "enable_deletion_protection" {
  description = "Enable ALB deletion protection"
  type        = bool
  default     = false
}

variable "enable_waf" {
  description = "Attach AWS WAF Web ACL to the ALB"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key ARN for encryption at rest"
  type        = string
  default     = null
}

variable "docker_image_tag" {
  description = "Container image tag deployed to EC2 (set by CI/CD)"
  type        = string
  default     = "latest"
}

variable "ecr_repository_url" {
  description = "ECR repository URL for the application image"
  type        = string
  default     = ""
}

variable "cloudtrail_bucket_name" {
  description = "S3 bucket for CloudTrail logs (created if empty)"
  type        = string
  default     = ""
}

variable "enable_config" {
  description = "Enable AWS Config recorder and delivery channel"
  type        = bool
  default     = false
}

variable "enable_cloudtrail" {
  description = "Enable CloudTrail trail (disable on sandbox if IAM/CloudTrail is blocked)"
  type        = bool
  default     = false
}

variable "enable_guardduty" {
  description = "Unused — GuardDuty removed from root module for sandbox SSO"
  type        = bool
  default     = false
}

variable "enable_inspector" {
  description = "Enable Amazon Inspector"
  type        = bool
  default     = false
}

variable "enable_ssm_patching" {
  description = "Create SSM patch baseline and maintenance window (requires ssm:CreatePatchBaseline)"
  type        = bool
  default     = false
}
