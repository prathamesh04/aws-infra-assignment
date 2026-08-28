output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "app_log_group" {
  value = aws_cloudwatch_log_group.app.name
}

output "system_log_group" {
  value = aws_cloudwatch_log_group.system.name
}

output "alb_log_group" {
  value = aws_cloudwatch_log_group.alb.name
}
