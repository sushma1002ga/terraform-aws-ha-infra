################################################################################
# ElastiCache Module — Redis Cluster with Encryption
################################################################################

resource "random_password" "redis_auth" {
  length  = 64
  special = false # Redis auth tokens cannot contain certain special chars
}

# Store Redis auth token in Secrets Manager
resource "aws_secretsmanager_secret" "redis_auth" {
  name                    = "${var.name_prefix}/redis/auth-token"
  description             = "Auth token for ${var.name_prefix} Redis cluster"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 0

  tags = {
    Name = "${var.name_prefix}-redis-auth"
  }
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id     = aws_secretsmanager_secret.redis_auth.id
  secret_string = random_password.redis_auth.result
}

# ─── Redis Replication Group ─────────────────────────────────────────────────

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.name_prefix}-redis"
  description          = "Redis cluster for ${var.name_prefix}"

  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.node_type
  num_cache_clusters   = var.num_cache_clusters
  parameter_group_name = aws_elasticache_parameter_group.this.name
  port                 = 6379

  # Networking
  subnet_group_name  = var.subnet_group_name
  security_group_ids = [var.security_group_id]

  # HA
  automatic_failover_enabled = var.multi_az_enabled
  multi_az_enabled           = var.multi_az_enabled

  # Encryption
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn
  auth_token                 = random_password.redis_auth.result

  # Maintenance
  maintenance_window         = "sun:05:00-sun:06:00"
  snapshot_retention_limit   = var.snapshot_retention_limit
  snapshot_window            = "03:00-04:00"
  auto_minor_version_upgrade = true
  apply_immediately          = var.environment == "dev" ? true : false

  # Notifications
  notification_topic_arn = var.sns_topic_arn

  tags = {
    Name = "${var.name_prefix}-redis"
  }

  lifecycle {
    ignore_changes = [auth_token]
  }
}

# ─── Parameter Group ─────────────────────────────────────────────────────────

resource "aws_elasticache_parameter_group" "this" {
  name   = "${var.name_prefix}-redis-params"
  family = var.parameter_group_family

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  tags = {
    Name = "${var.name_prefix}-redis-params"
  }
}
