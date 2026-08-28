variable "environment" {
  type        = string
  description = "Environment name"
}

variable "ami_id" {
  type        = string
  description = "AMI ID for EC2 instances"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "app_image" {
  type        = string
  description = "Docker image URI (ECR) to run on instances"
}

variable "instance_profile_name" {
  type        = string
  description = "IAM instance profile name attached to instances"
}

variable "security_group_id" {
  type        = string
  description = "Security group ID for the app instances"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs to place instances in"
}

variable "target_group_arns" {
  type        = list(string)
  description = "ALB target group ARNs to register instances against"
}

variable "root_volume_size" {
  type    = number
  default = 20
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 3
}

variable "desired_capacity" {
  type    = number
  default = 1
}

variable "cpu_high_threshold" {
  type    = number
  default = 80
}

variable "cpu_low_threshold" {
  type    = number
  default = 20
}

variable "sns_topic_arn" {
  type        = string
  description = "SNS topic ARN for alarms"
}

variable "app_log_group" {
  type        = string
  description = "CloudWatch log group for application logs"
}

variable "system_log_group" {
  type        = string
  description = "CloudWatch log group for system logs"
}
