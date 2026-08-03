variable "name_prefix" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "image_retention_count" {
  type    = number
  default = 10
}

variable "tags" {
  type = map(string)
}

## OUTPUTS ##

output "repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "repository_arn" {
  value = aws_ecr_repository.app.arn
}

output "repository_name" {
  value = aws_ecr_repository.app.name
}