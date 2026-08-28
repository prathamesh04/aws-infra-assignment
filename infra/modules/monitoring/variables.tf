variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "alert_email" {
  type        = string
  default     = ""
  description = "Email to receive SNS alerts"
}

variable "alb_arn_suffix" {
  type        = string
  description = "ALB arn suffix for CloudWatch dimensions"
}

variable "db_instance_identifier" {
  type        = string
  description = "RDS instance identifier for metrics"
}

variable "latency_threshold" {
  type    = number
  default = 1.0
}

variable "db_connections_threshold" {
  type    = number
  default = 80
}
