data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "db_monitoring_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_app" {
  name               = "${var.environment}-ec2-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ec2_app_ecr_read" {
  role       = aws_iam_role.ec2_app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ec2_app_ssm" {
  role       = aws_iam_role.ec2_app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_app_cloudwatch" {
  role       = aws_iam_role.ec2_app.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_app" {
  name = "${var.environment}-ec2-app-profile"
  role = aws_iam_role.ec2_app.name
}

resource "aws_iam_role" "db_monitoring" {
  name               = "${var.environment}-rds-monitoring-role"
  assume_role_policy = data.aws_iam_policy_document.db_monitoring_assume_role.json
}

resource "aws_iam_role_policy_attachment" "db_monitoring" {
  role       = aws_iam_role.db_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

module "networking" {
  source             = "../../modules/networking"
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  azs                = var.azs
  enable_nat_gateway = var.enable_nat_gateway
}

module "security" {
  source            = "../../modules/security"
  environment       = var.environment
  vpc_id            = module.networking.vpc_id
  enable_bastion    = var.enable_bastion
  admin_cidr_blocks = var.admin_cidr_blocks
}

module "monitoring" {
  source                 = "../../modules/monitoring"
  environment            = var.environment
  region                 = data.aws_region.current.name
  alert_email            = var.alert_email
  log_retention_days     = var.log_retention_days
  alb_arn_suffix         = module.loadbalancer.alb_arn_suffix
  db_instance_identifier = module.database.db_identifier
}

module "database" {
  source                       = "../../modules/database"
  environment                  = var.environment
  instance_class               = var.db_instance_class
  allocated_storage            = var.db_allocated_storage
  db_name                      = var.db_name
  db_username                  = var.db_username
  db_password                  = var.db_password
  db_subnet_group_name         = module.networking.database_subnet_group_name
  security_group_id            = module.security.database_sg_id
  multi_az                     = var.multi_az
  backup_retention_period      = var.backup_retention_period
  deletion_protection          = var.deletion_protection
  skip_final_snapshot          = var.skip_final_snapshot
  monitoring_interval          = var.db_monitoring_interval
  monitoring_role_arn          = aws_iam_role.db_monitoring.arn
  performance_insights_enabled = var.performance_insights_enabled
  sns_topic_arn                = module.monitoring.sns_topic_arn
}

module "loadbalancer" {
  source              = "../../modules/loadbalancer"
  environment         = var.environment
  public_subnet_ids   = module.networking.public_subnet_ids
  security_group_id   = module.security.alb_sg_id
  vpc_id              = module.networking.vpc_id
  log_bucket          = aws_s3_bucket.access_logs.id
  enable_access_logs  = var.enable_alb_access_logs
  deletion_protection = var.alb_deletion_protection
  certificate_arn     = var.acm_certificate_arn
}

module "compute" {
  source                = "../../modules/compute"
  environment           = var.environment
  ami_id                = data.aws_ami.amazon_linux.id
  instance_type         = var.instance_type
  region                = data.aws_region.current.name
  app_image             = var.app_image
  instance_profile_name = aws_iam_instance_profile.ec2_app.name
  security_group_id     = module.security.app_sg_id
  subnet_ids            = module.networking.private_subnet_ids
  target_group_arns     = module.loadbalancer.target_group_arns
  min_size              = var.asg_min_size
  max_size              = var.asg_max_size
  desired_capacity      = var.asg_desired_capacity
  sns_topic_arn         = module.monitoring.sns_topic_arn
  app_log_group         = module.monitoring.app_log_group
  system_log_group      = module.monitoring.system_log_group
}

resource "aws_s3_bucket" "access_logs" {
  bucket        = "${var.environment}-${data.aws_caller_identity.current.account_id}-alb-logs"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}
