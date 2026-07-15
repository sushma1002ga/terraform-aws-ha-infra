################################################################################
# RDS Module — Aurora PostgreSQL Multi-AZ Cluster
################################################################################

# ─── Random password for DB master user ──────────────────────────────────────

resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+[]{}|:,.<>?"
}

# Store password in Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.name_prefix}/rds/master-password"
  description             = "Master password for ${var.name_prefix} Aurora cluster"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 0

  tags = {
    Name = "${var.name_prefix}-db-password"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
    engine   = "aurora-postgresql"
    host     = aws_rds_cluster.this.endpoint
    port     = 5432
    dbname   = var.database_name
  })
}

# ─── Aurora Cluster ───────────────────────────────────────────────────────────

resource "aws_rds_cluster" "this" {
  cluster_identifier = "${var.name_prefix}-aurora"
  engine             = "aurora-postgresql"
  engine_version     = var.engine_version
  engine_mode        = "provisioned"

  database_name   = var.database_name
  master_username = var.master_username
  master_password = random_password.master.result

  # Networking
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [var.security_group_id]
  port                   = 5432

  # Encryption
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  # Backup & Recovery
  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot        = true
  final_snapshot_identifier    = "${var.name_prefix}-final-snapshot"
  skip_final_snapshot          = var.environment == "dev" ? true : false

  # Protection
  deletion_protection             = var.deletion_protection
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Serverless V2 scaling (optional)
  dynamic "serverlessv2_scaling_configuration" {
    for_each = var.enable_serverless ? [1] : []
    content {
      min_capacity = var.serverless_min_capacity
      max_capacity = var.serverless_max_capacity
    }
  }

  tags = {
    Name = "${var.name_prefix}-aurora"
  }

  lifecycle {
    ignore_changes = [master_password]
  }
}

# ─── Aurora Instances ─────────────────────────────────────────────────────────

resource "aws_rds_cluster_instance" "this" {
  count = var.instance_count

  identifier         = "${var.name_prefix}-aurora-${count.index}"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = var.enable_serverless ? "db.serverless" : var.instance_class
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  publicly_accessible             = false
  auto_minor_version_upgrade      = true
  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.kms_key_arn

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  tags = {
    Name = "${var.name_prefix}-aurora-${count.index}"
  }
}

# ─── Enhanced Monitoring Role ────────────────────────────────────────────────

resource "aws_iam_role" "rds_monitoring" {
  name = "${var.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.name_prefix}-rds-monitoring-role"
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
