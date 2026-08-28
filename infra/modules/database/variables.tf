variable "environment" {
  type        = string
  description = "Environment name"
}

variable "instance_class" {
  type        = string
  description = "RDS instance class"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "max_allocated_storage" {
  type    = number
  default = 100
}

variable "db_name" {
  type        = string
  description = "Database name"
}

variable "db_username" {
  type        = string
  description = "Database username"
}

variable "db_password" {
  type        = string
  description = "Database password (managed via Secret Manager/SSM in real usage)"
  sensitive   = true
}

variable "db_subnet_group_name" {
  type        = string
  description = "DB subnet group name"
}

variable "security_group_id" {
  type        = string
  description = "Security group ID for the database"
}

variable "multi_az" {
  type        = bool
  default     = false
  description = "Multi-AZ deployment. Use true for production."
}

variable "backup_retention_period" {
  type    = number
  default = 7
}

variable "backup_window" {
  type    = string
  default = "03:00-04:00"
}

variable "maintenance_window" {
  type    = string
  default = "sun:04:00-sun:05:00"
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  type    = bool
  default = true
}

variable "monitoring_interval" {
  type    = number
  default = 60
}

variable "monitoring_role_arn" {
  type        = string
  default     = ""
  description = "RDS enhanced monitoring IAM role ARN"
}

variable "performance_insights_enabled" {
  type    = bool
  default = false
}

variable "sns_topic_arn" {
  type        = string
  description = "SNS topic ARN for DB event notifications"
}
