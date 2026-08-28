variable "environment" {
  type        = string
  description = "Environment name (staging/production)"
}

variable "region" {
  type        = string
  default     = "ap-south-1"
  description = "AWS region"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VPC CIDR block"
}

variable "azs" {
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
  description = "Availability zones"
}

variable "enable_nat_gateway" {
  type    = bool
  default = true
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type"
}

variable "root_volume_size" {
  type    = number
  default = 20
}

variable "asg_min_size" {
  type    = number
  default = 1
}

variable "asg_max_size" {
  type    = number
  default = 2
}

variable "asg_desired_capacity" {
  type    = number
  default = 1
}

variable "db_instance_class" {
  type        = string
  default     = "db.t3.micro"
  description = "RDS instance class"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_name" {
  type        = string
  default     = "appdb"
  description = "Database name"
}

variable "db_username" {
  type        = string
  default     = "appuser"
  description = "Database master username"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Database master password (prefer AWS Secrets Manager)"
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "backup_retention_period" {
  type    = number
  default = 7
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  type    = bool
  default = true
}

variable "db_monitoring_interval" {
  type    = number
  default = 60
}

variable "performance_insights_enabled" {
  type    = bool
  default = false
}

variable "app_image" {
  type        = string
  description = "Docker image URI from ECR"
}

variable "alert_email" {
  type    = string
  default = ""
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "acm_certificate_arn" {
  type    = string
  default = ""
}

variable "alb_deletion_protection" {
  type    = bool
  default = false
}

variable "enable_alb_access_logs" {
  type    = bool
  default = false
}

variable "enable_bastion" {
  type    = bool
  default = false
}

variable "admin_cidr_blocks" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}
