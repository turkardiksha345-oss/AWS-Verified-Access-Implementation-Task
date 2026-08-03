# ---------------------------------------------------------------------------
# SNS Module — operational alarm notifications
# ---------------------------------------------------------------------------


resource "aws_sns_topic" "alarms" {
  name              = "${var.name_prefix}-alarms"
  kms_master_key_id = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alarms"
  })
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

variable "name_prefix" {
  type = string
}

variable "alarm_email" {
  type = string
}

variable "kms_key_arn" {
  type    = string
  default = null
}

variable "tags" {
  type = map(string)
}


output "topic_arn" {
  value = aws_sns_topic.alarms.arn
}

output "topic_name" {
  value = aws_sns_topic.alarms.name
}
