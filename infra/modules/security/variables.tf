variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "bastion_sg_id" {
  type        = string
  default     = ""
  description = "Optional bastion SG to allow SSH from"
}

variable "enable_bastion" {
  type    = bool
  default = false
}

variable "admin_cidr_blocks" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}
