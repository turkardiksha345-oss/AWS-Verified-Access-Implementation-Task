# ---------------------------------------------------------------------------
# EC2 Module — Auto Scaling Group with hardened Amazon Linux 2023 instances
# ---------------------------------------------------------------------------

variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "instance_profile_arn" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "min_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "desired_capacity" {
  type = number
}

variable "app_port" {
  type = number
}

variable "target_group_arn" {
  type = string
}

variable "kms_key_arn" {
  type    = string
  default = null
}

variable "docker_image_tag" {
  type = string
}

variable "ecr_repository_url" {
  type = string
}

variable "log_group_name" {
  type = string
}

variable "enable_ssm_patching" {
  description = "Create SSM patch baseline / maintenance window (needs extra IAM)"
  type        = bool
  default     = false
}

variable "tags" {
  type = map(string)
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.name_prefix}-lt-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  iam_instance_profile {
    arn = var.instance_profile_arn
  }

  vpc_security_group_ids = [var.security_group_id]

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    app_port           = var.app_port
    log_group_name     = var.log_group_name
    docker_image_tag   = var.docker_image_tag
    ecr_repository_url = var.ecr_repository_url
    aws_region         = data.aws_region.current.name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.name_prefix}-app"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_region" "current" {}

resource "aws_autoscaling_group" "app" {
  name                      = "${var.name_prefix}-asg"
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [var.target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  # Don't block Terraform on Target Group health (image push / bootstrap can lag).
  wait_for_capacity_timeout = "0"

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      max_healthy_percentage = 100
      instance_warmup        = 300
      # Skip instances already matching the new launch template (faster safe refreshes).
      skip_matching = true
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-app"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  # Do not use create_before_destroy with a fixed ASG name — AWS rejects duplicate names.
}

# SSM Patch Manager — optional (sandbox SSO often lacks CreatePatchBaseline)
resource "aws_ssm_patch_baseline" "amazon_linux" {
  count = var.enable_ssm_patching ? 1 : 0

  name             = "${var.name_prefix}-al2023-baseline"
  operating_system = "AMAZON_LINUX_2023"

  approval_rule {
    approve_after_days = 7

    patch_filter {
      key    = "CLASSIFICATION"
      values = ["Security", "Bugfix"]
    }
  }

  tags = var.tags
}

resource "aws_ssm_patch_group" "app" {
  count = var.enable_ssm_patching ? 1 : 0

  baseline_id = aws_ssm_patch_baseline.amazon_linux[0].id
  patch_group = "${var.name_prefix}-app"
}

resource "aws_ssm_maintenance_window" "patching" {
  count = var.enable_ssm_patching ? 1 : 0

  name     = "${var.name_prefix}-patching"
  schedule = "cron(0 4 ? * SUN *)"
  duration = 2
  cutoff   = 1

  tags = var.tags
}

resource "aws_ssm_maintenance_window_target" "app" {
  count = var.enable_ssm_patching ? 1 : 0

  window_id     = aws_ssm_maintenance_window.patching[0].id
  name          = "${var.name_prefix}-app-targets"
  resource_type = "INSTANCE"

  targets {
    key    = "tag:Environment"
    values = [var.tags["Environment"]]
  }
}

resource "aws_ssm_maintenance_window_task" "patch" {
  count = var.enable_ssm_patching ? 1 : 0

  window_id        = aws_ssm_maintenance_window.patching[0].id
  task_type        = "RUN_COMMAND"
  task_arn         = "AWS-RunPatchBaseline"
  priority         = 1
  service_role_arn = aws_iam_role.ssm_maintenance[0].arn
  max_concurrency  = "2"
  max_errors       = "1"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.app[0].id]
  }

  task_invocation_parameters {
    run_command_parameters {
      parameter {
        name   = "Operation"
        values = ["Install"]
      }
      parameter {
        name   = "RebootOption"
        values = ["RebootIfNeeded"]
      }
    }
  }
}

resource "aws_iam_role" "ssm_maintenance" {
  count = var.enable_ssm_patching ? 1 : 0

  name = "${var.name_prefix}-ssm-maintenance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ssm.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm_maintenance" {
  count = var.enable_ssm_patching ? 1 : 0

  role       = aws_iam_role.ssm_maintenance[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMMaintenanceWindowRole"
}

output "asg_name" {
  value = aws_autoscaling_group.app.name
}

output "instance_ids" {
  value       = aws_autoscaling_group.app.id
  description = "ASG ID — use SSM to list instances"
}

output "launch_template_id" {
  value = aws_launch_template.app.id
}
