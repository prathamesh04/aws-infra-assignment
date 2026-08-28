variable "environment" {
  type        = string
  description = "Environment name"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for ALB"
}

variable "security_group_id" {
  type        = string
  description = "Security group ID for ALB"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "log_bucket" {
  type        = string
  default     = ""
  description = "S3 bucket for access logs"
}

variable "enable_access_logs" {
  type    = bool
  default = false
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "certificate_arn" {
  type        = string
  default     = ""
  description = "ACM certificate ARN for HTTPS listener"
}
