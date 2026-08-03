variable "name_prefix" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "tags" {
  type = map(string)
}


output "certificate_arn" {
  value = aws_acm_certificate_validation.main.certificate_arn
}

output "validation_records" {
  description = "CNAME records for ACM TLS validation — send to your DNS manager"
  value = [
    for option in local.validation_options : {
      name  = option.name
      type  = option.type
      value = option.record
    }
  ]
}