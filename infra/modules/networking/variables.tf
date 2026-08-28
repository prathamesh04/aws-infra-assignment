variable "environment" {
  type        = string
  description = "Environment name (staging/production)"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "azs" {
  type        = list(string)
  description = "List of availability zones"
}

variable "enable_nat_gateway" {
  type        = bool
  default     = true
  description = "Enable NAT gateway for private subnets"
}
