# ---------------------------------------------------------------------------
# Security Groups — least-privilege network access controls
# ---------------------------------------------------------------------------

variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "app_port" {
  type = number
}

variable "vpc_cidr_block" {
  type = string
}

variable "tags" {
  type = map(string)
}

# ALB — HTTPS only from Verified Access ENIs (no public CIDR on ALB).
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from Verified Access endpoint only"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.verified_access.id]
  }

  egress {
    description = "Forward to application targets"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-sg"
  })

  # Fixed SG name + create_before_destroy causes Duplicate on replacement.
}

# EC2 — only accepts traffic from ALB security group
resource "aws_security_group" "ec2" {
  name        = "${var.name_prefix}-ec2-sg"
  description = "Security group for application EC2 instances"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Application port from ALB only"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "HTTPS for package updates and AWS API calls"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS resolution"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ec2-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# VPC Endpoints security group for SSM (no SSH required)
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.name_prefix}-vpce-sg"
  description = "Security group for VPC interface endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpce-sg"
  })
}

# Verified Access endpoint ENIs (attachment_type = vpc requires security groups)
resource "aws_security_group" "verified_access" {
  name        = "${var.name_prefix}-va-sg"
  description = "Security group for Verified Access endpoint"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from clients via Verified Access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS to ALB"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-va-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "ec2_security_group_id" {
  value = aws_security_group.ec2.id
}

output "vpc_endpoints_security_group_id" {
  value = aws_security_group.vpc_endpoints.id
}

output "verified_access_security_group_id" {
  value = aws_security_group.verified_access.id
}
