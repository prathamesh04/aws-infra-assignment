output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.networking.vpc_id
}

output "public_subnets" {
  description = "IDs of the public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnets" {
  description = "IDs of the private subnets"
  value       = module.networking.private_subnet_ids
}

output "alb_dns_name" {
  description = "DNS name of the application load balancer"
  value       = module.loadbalancer.alb_dns_name
}

output "app_url" {
  description = "URL to access the application"
  value       = "http://${module.loadbalancer.alb_dns_name}"
}

output "db_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.database.db_endpoint
}

output "ec2_instance_ids" {
  description = "EC2 instance IDs (via ASG)"
  value       = module.compute.asg_name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = module.monitoring.sns_topic_arn
}

output "cloudwatch_dashboards" {
  description = "CloudWatch dashboards"
  value = [
    "${var.environment}-infrastructure-dashboard",
    "${var.environment}-application-dashboard",
  ]
}
