# ============================================================
# Module: RDS — Amazon RDS MySQL
# ============================================================

# ─── Subnet Group ───────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.common_tags, { Name = "${var.project_name}-rds-subnet-group" })
}

# ─── Security Group ─────────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "RDS MySQL security group"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from EKS nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
    cidr_blocks     = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${var.project_name}-rds-sg" })
}

# ─── Random password ────────────────────────────────────────
resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}?"
}

# ─── SSM Parameter для пароля ───────────────────────────────
resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.project_name}/rds/password"
  description = "RDS MySQL master password"
  type        = "SecureString"
  value       = random_password.db_password.result

  tags = var.common_tags
}

resource "aws_ssm_parameter" "db_endpoint" {
  name        = "/${var.project_name}/rds/endpoint"
  description = "RDS MySQL endpoint"
  type        = "String"
  value       = aws_db_instance.main.endpoint

  tags = var.common_tags
}

# ─── RDS Instance ───────────────────────────────────────────
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-mysql"

  # Engine
  engine               = "mysql"
  engine_version       = var.mysql_version
  instance_class       = var.instance_class
  parameter_group_name = aws_db_parameter_group.main.name

  # Storage
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  # Credentials
  db_name  = var.database_name
  username = var.master_username
  password = random_password.db_password.result

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = 3306

  # Backup
  backup_retention_period   = var.backup_retention_days
  backup_window             = "03:00-04:00"
  maintenance_window        = "Mon:04:00-Mon:05:00"
  delete_automated_backups  = false
  copy_tags_to_snapshot     = true
  final_snapshot_identifier = "${var.project_name}-mysql-final-snapshot"
  skip_final_snapshot       = false

  # Monitoring
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn
  enabled_cloudwatch_logs_exports = ["error", "slowquery"]
  performance_insights_enabled = false

  # Misc
  auto_minor_version_upgrade = true
  deletion_protection        = var.deletion_protection
  multi_az                   = var.multi_az

  tags = merge(var.common_tags, { Name = "${var.project_name}-mysql" })

  lifecycle {
    ignore_changes = [password]
  }
}

# ─── Parameter Group ────────────────────────────────────────
resource "aws_db_parameter_group" "main" {
  name   = "${var.project_name}-mysql-params"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }
  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }
  parameter {
    name  = "slow_query_log"
    value = "1"
  }
  parameter {
    name  = "long_query_time"
    value = "2"
  }

  tags = var.common_tags
}

# ─── IAM Role for Enhanced Monitoring ───────────────────────
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"]
  tags                = var.common_tags
}
