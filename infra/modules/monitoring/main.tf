resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.environment}/app"
  retention_in_days = var.log_retention_days
  tags = {
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "system" {
  name              = "/${var.environment}/system"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "alb" {
  name              = "${var.environment}/alb/access"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_metric_filter" "http_5xx" {
  name           = "${var.environment}-http-5xx-count"
  log_group_name = aws_cloudwatch_log_group.alb.name
  pattern        = ""

  metric_transformation {
    name          = "HTTP5xxCount"
    namespace     = "Application"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "error_logs" {
  name           = "${var.environment}-error-log-count"
  log_group_name = aws_cloudwatch_log_group.app.name
  pattern        = "ERROR"

  metric_transformation {
    name          = "ErrorLogCount"
    namespace     = "Application"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_sns_topic" "alerts" {
  name = "${var.environment}-alerts"
  tags = {
    Environment = var.environment
  }
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.environment}-alb-5xx-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "High 5xx errors from ALB"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_latency" {
  alarm_name          = "${var.environment}-alb-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = var.latency_threshold
  alarm_description   = "ALB latency above threshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "db_connections" {
  alarm_name          = "${var.environment}-db-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.db_connections_threshold
  alarm_description   = "High DB connections"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    DBInstanceIdentifier = var.db_instance_identifier
  }
}

resource "aws_cloudwatch_dashboard" "infrastructure" {
  dashboard_name = "${var.environment}-infrastructure-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", { stat = "Average" }],
            ["AWS/EC2", "MemoryUtilization", { stat = "Average" }],
            ["AWS/EC2", "DiskSpaceUtilization", { stat = "Average" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "EC2 Infrastructure Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", { stat = "Sum" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", { stat = "Sum" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", { stat = "Sum" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Load Balancer Request & Error Rates"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", { stat = "Average" }],
            ["AWS/RDS", "DatabaseConnections", { stat = "Average" }],
            ["AWS/RDS", "FreeStorageSpace", { stat = "Average" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "RDS Database Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["Application", "ErrorLogCount", { stat = "Average" }],
            ["Application", "HTTP5xxCount", { stat = "Average" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Application Error Metrics"
          period  = 300
        }
      }
    ]
  })
}

resource "aws_cloudwatch_dashboard" "application" {
  dashboard_name = "${var.environment}-application-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["Application", "RequestRate", { stat = "Sum" }],
            ["Application", "RequestLatency", { stat = "Average" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Application Request Rate & Latency"
          period  = 60
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["Application", "ErrorRate", { stat = "Average" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Application Error Rate"
          period  = 60
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          query  = "SOURCE '${aws_cloudwatch_log_group.app.name}' | fields @timestamp, @message | sort @timestamp desc | limit 20"
          region = var.region
          title  = "Recent Application Logs"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          query  = "SOURCE '${aws_cloudwatch_log_group.system.name}' | fields @timestamp, @message | sort @timestamp desc | limit 20"
          region = var.region
          title  = "Recent System Logs"
        }
      }
    ]
  })
}
