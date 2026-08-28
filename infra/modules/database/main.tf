resource "aws_db_instance" "this" {
  identifier = "${var.environment}-postgres"

  engine                = "postgres"
  engine_version        = "16.11"
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [var.security_group_id]

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot

  monitoring_interval          = var.monitoring_interval
  monitoring_role_arn          = var.monitoring_role_arn
  performance_insights_enabled = var.performance_insights_enabled

  auto_minor_version_upgrade = true

  tags = {
    Name        = "${var.environment}-postgres"
    Environment = var.environment
  }
}

resource "aws_db_parameter_group" "this" {
  family = "postgres16"
  name   = "${var.environment}-postgres-pg"

  parameter {
    name  = "log_connections"
    value = "1"
  }
  parameter {
    name  = "log_disconnections"
    value = "1"
  }
}

resource "aws_db_event_subscription" "this" {
  name      = "${var.environment}-db-events"
  sns_topic = var.sns_topic_arn

  source_type = "db-instance"
  source_ids  = [aws_db_instance.this.identifier]

  event_categories = ["availability", "backup", "maintenance", "creation", "deletion"]
}
