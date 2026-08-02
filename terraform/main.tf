# ---------------------------------------------------------------------------
# Root composition — wires all modules together
# ---------------------------------------------------------------------------

module "logs" {
  source = "./modules/logs"

  name_prefix        = local.name_prefix
  aws_region         = var.aws_region
  log_retention_days = var.log_retention_days
  kms_key_arn        = var.kms_key_arn
  cloudtrail_bucket  = var.cloudtrail_bucket_name
  enable_config      = var.enable_config
  enable_cloudtrail  = var.enable_cloudtrail
  tags               = local.common_tags
}

module "sns" {
  source = "./modules/sns"

  name_prefix = local.name_prefix
  alarm_email = var.alarm_email
  kms_key_arn = module.logs.kms_key_arn
  tags        = local.common_tags
}

module "vpc" {
  source = "./modules/vpc"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  log_retention_days   = var.log_retention_days
  kms_key_arn          = module.logs.kms_key_arn
  flow_logs_bucket_arn = module.logs.flow_logs_bucket_arn
  tags                 = local.common_tags
}

module "security_groups" {
  source = "./modules/security-groups"

  name_prefix    = local.name_prefix
  vpc_id         = module.vpc.vpc_id
  app_port       = var.app_port
  vpc_cidr_block = var.vpc_cidr
  tags           = local.common_tags
}

module "vpc_endpoints" {
  source = "./modules/vpc-endpoints"

  name_prefix        = local.name_prefix
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_id  = module.security_groups.vpc_endpoints_security_group_id
  tags               = local.common_tags
}

module "ecr" {
  source = "./modules/ecr"
  count  = var.create_ecr_repository ? 1 : 0

  name_prefix = local.name_prefix
  kms_key_arn = module.logs.kms_key_arn
  tags        = local.common_tags
}

module "iam" {
  source = "./modules/iam"

  providers = {
    aws                 = aws
    aws.no_default_tags = aws.no_default_tags
  }

  name_prefix          = local.name_prefix
  aws_region           = var.aws_region
  log_group_arns       = module.logs.log_group_arns
  secrets_manager_arns = module.logs.secrets_manager_arns
  s3_bucket_arns       = [module.logs.alb_logs_bucket_arn, module.logs.flow_logs_bucket_arn]
  ecr_repository_arns  = var.create_ecr_repository ? [module.ecr[0].repository_arn] : []
  github_project_path  = var.github_project_path
  github_url           = var.github_url
  enable_github_oidc   = var.enable_github_oidc
  tags                 = local.common_tags
}

module "acm" {
  source = "./modules/acm"

  name_prefix = local.name_prefix
  domain_name = local.fqdn
  tags        = local.common_tags
}

module "alb" {
  source = "./modules/alb"

  name_prefix                = local.name_prefix
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.private_subnet_ids
  security_group_id          = module.security_groups.alb_security_group_id
  certificate_arn            = module.acm.certificate_arn
  app_port                   = var.app_port
  enable_deletion_protection = var.enable_deletion_protection
  enable_waf                 = var.enable_waf
  alb_logs_bucket            = module.logs.alb_logs_bucket_name
  tags                       = local.common_tags

  depends_on = [module.acm]
}

module "ec2" {
  source = "./modules/ec2"

  name_prefix          = local.name_prefix
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  security_group_id    = module.security_groups.ec2_security_group_id
  instance_profile_arn = module.iam.ec2_instance_profile_arn
  instance_type        = var.ec2_instance_type
  min_size             = var.ec2_min_size
  max_size             = var.ec2_max_size
  desired_capacity     = var.ec2_desired_capacity
  app_port             = var.app_port
  target_group_arn     = module.alb.target_group_arn
  kms_key_arn          = module.logs.kms_key_arn
  docker_image_tag     = var.docker_image_tag
  ecr_repository_url   = var.create_ecr_repository ? module.ecr[0].repository_url : var.ecr_repository_url
  log_group_name       = module.logs.application_log_group_name
  enable_ssm_patching  = var.enable_ssm_patching
  tags                 = local.common_tags
}

module "identity_center" {
  count  = var.manage_identity_center ? 1 : 0
  source = "./modules/identity-center"

  providers = {
    aws = aws.identity_center
  }

  name_prefix     = local.name_prefix
  approved_groups = var.approved_groups
  approved_domain = var.approved_email_domain
  users           = var.identity_center_users
  tags            = local.common_tags
}

module "verified_access" {
  source = "./modules/verified-access"

  name_prefix       = local.name_prefix
  fqdn              = local.fqdn
  certificate_arn   = module.acm.certificate_arn
  load_balancer_arn = module.alb.alb_arn
  # Same private subnets as internal ALB (VA → private ALB → private EC2).
  subnet_ids                   = module.vpc.private_subnet_ids
  security_group_ids           = [module.security_groups.verified_access_security_group_id]
  identity_center_instance_arn = local.identity_center_instance_arn
  cedar_group_policy           = local.cedar_group_policy
  cedar_endpoint_policy        = local.cedar_endpoint_policy
  cedar_policy_version         = var.cedar_policy_version
  log_group_name               = module.logs.verified_access_log_group_name
  tags                         = local.common_tags

  depends_on = [module.alb]
}

module "cloudwatch" {
  source = "./modules/cloudwatch"

  name_prefix                    = local.name_prefix
  log_retention_days             = var.log_retention_days
  verified_access_log_group_name = module.logs.verified_access_log_group_name
  application_log_group_name     = module.logs.application_log_group_name
  alb_arn_suffix                 = module.alb.alb_arn_suffix
  target_group_arn_suffix        = module.alb.target_group_arn_suffix
  kms_key_arn                    = module.logs.kms_key_arn
  tags                           = local.common_tags
}

module "monitoring" {
  source = "./modules/monitoring"

  name_prefix                    = local.name_prefix
  aws_region                     = var.aws_region
  sns_topic_arn                  = module.sns.topic_arn
  alb_arn_suffix                 = module.alb.alb_arn_suffix
  target_group_arn_suffix        = module.alb.target_group_arn_suffix
  asg_name                       = module.ec2.asg_name
  verified_access_log_group_name = module.logs.verified_access_log_group_name
  application_log_group_name     = module.logs.application_log_group_name
  environment                    = var.environment
  tags                           = local.common_tags
}

# Observability beyond VA/app CloudWatch + SNS is optional (see enable_* in tfvars).
# GuardDuty / Config / SSM patching are optional for constrained IAM permissions.
