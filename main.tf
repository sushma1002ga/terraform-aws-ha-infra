################################################################################
# Root Module — Orchestrates All Infrastructure Modules
#
# Usage:
#   terraform workspace new dev
#   terraform plan -var-file=environments/dev.tfvars
#   terraform apply -var-file=environments/dev.tfvars
################################################################################

# ─── 1. KMS Encryption Keys ──────────────────────────────────────────────────

module "kms" {
  source = "./modules/kms"

  name_prefix         = local.name_prefix
  enable_multi_region = local.config.enable_dr
}

# ─── 2. IAM Roles & Policies ─────────────────────────────────────────────────

module "iam" {
  source = "./modules/iam"

  name_prefix         = local.name_prefix
  kms_key_arn         = module.kms.app_key_arn
  create_bastion_role = var.enable_bastion
}

# ─── 3. VPC — Multi-AZ Networking ────────────────────────────────────────────

module "vpc" {
  source = "./modules/vpc"

  name_prefix             = local.name_prefix
  vpc_cidr                = var.vpc_cidr
  azs                     = local.azs
  nat_gateway_count       = local.config.nat_gateway_count
  enable_flow_logs        = var.enable_vpc_flow_logs
  flow_log_role_arn       = module.iam.flow_logs_role_arn
  flow_log_retention_days = 30
  kms_key_arn             = module.kms.logs_key_arn
}

# ─── 4. Security Groups ──────────────────────────────────────────────────────

module "security_groups" {
  source = "./modules/security-groups"

  name_prefix           = local.name_prefix
  vpc_id                = module.vpc.vpc_id
  container_port        = var.container_port
  allowed_bastion_cidrs = var.allowed_bastion_cidrs
  create_bastion_sg     = var.enable_bastion
}

# ─── 5. S3 Buckets ───────────────────────────────────────────────────────────

module "s3" {
  source = "./modules/s3"

  name_prefix        = local.name_prefix
  environment        = local.environment
  kms_key_arn        = module.kms.app_key_arn
  log_retention_days = 90
  enable_replication = local.config.enable_dr
  dr_bucket_arn      = "" # Set to DR bucket ARN when DR is configured
}

# ─── 5b. ECR — Container Registry ────────────────────────────────────────────

module "ecr" {
  source = "./modules/ecr"

  name_prefix = local.name_prefix
  environment = local.environment
  kms_key_arn = module.kms.app_key_arn
}

# ─── 6. Route53 DNS Zone ─────────────────────────────────────────────────────

module "route53" {
  source = "./modules/route53"

  name_prefix               = local.name_prefix
  domain_name               = var.domain_name
  create_zone               = var.create_dns_zone
  primary_alb_dns           = module.alb.alb_dns_name
  primary_alb_zone_id       = module.alb.alb_zone_id
  cloudfront_domain_name    = module.cloudfront.distribution_domain_name
  cloudfront_hosted_zone_id = module.cloudfront.distribution_hosted_zone_id
  enable_dr                 = local.config.enable_dr
  enable_failover           = local.config.enable_dr
  create_cloudfront_record  = true
}

# ─── 7. ACM Certificates ─────────────────────────────────────────────────────

module "acm" {
  source = "./modules/acm"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  name_prefix = local.name_prefix
  domain_name = var.domain_name
  zone_id     = module.route53.zone_id
}

# ─── 8. Application Load Balancer ────────────────────────────────────────────

module "alb" {
  source = "./modules/alb"

  name_prefix                = local.name_prefix
  vpc_id                     = module.vpc.vpc_id
  public_subnet_ids          = module.vpc.public_subnet_ids
  security_group_id          = module.security_groups.alb_sg_id
  certificate_arn            = module.acm.primary_certificate_arn
  container_port             = var.container_port
  enable_deletion_protection = var.enable_deletion_protection
  enable_access_logs         = true
  access_logs_bucket         = module.s3.alb_logs_bucket_name
}

# ─── 9. ECS Fargate Cluster & Service ────────────────────────────────────────

module "ecs" {
  source = "./modules/ecs"

  name_prefix        = local.name_prefix
  environment        = local.environment
  aws_region         = var.primary_region
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_id  = module.security_groups.ecs_sg_id
  target_group_arn   = module.alb.target_group_arn
  execution_role_arn = module.iam.ecs_execution_role_arn
  task_role_arn      = module.iam.ecs_task_role_arn
  container_image    = "${module.ecr.repository_url}:latest"
  container_port     = 3000
  cpu                = local.config.ecs_cpu
  memory             = local.config.ecs_memory
  desired_count      = local.config.ecs_desired_count
  min_count          = local.config.ecs_min_count
  max_count          = local.config.ecs_max_count
  kms_key_arn        = module.kms.logs_key_arn
  kms_key_id         = module.kms.app_key_id

  # Banking app DB connection
  db_host       = module.rds.cluster_endpoint
  db_port       = module.rds.port
  db_name       = var.db_name
  db_secret_arn = module.rds.secret_arn

depends_on = [
    module.alb
]
}

# ─── 10. Aurora RDS Database ─────────────────────────────────────────────────

module "rds" {
  source = "./modules/rds"

  name_prefix             = local.name_prefix
  environment             = local.environment
  database_name           = var.db_name
  master_username         = var.db_master_username
  engine_version          = var.db_engine_version
  instance_count          = local.config.rds_instance_count
  instance_class          = local.config.rds_instance_class
  db_subnet_group_name    = module.vpc.db_subnet_group_name
  security_group_id       = module.security_groups.rds_sg_id
  kms_key_arn             = module.kms.rds_key_arn
  backup_retention_period = local.config.rds_backup_retention
  deletion_protection     = local.config.rds_deletion_protection
}

# ─── 11. ElastiCache Redis ───────────────────────────────────────────────────

module "elasticache" {
  source = "./modules/elasticache"

  name_prefix        = local.name_prefix
  environment        = local.environment
  node_type          = local.config.redis_node_type
  num_cache_clusters = local.config.redis_num_cache_nodes
  subnet_group_name  = module.vpc.elasticache_subnet_group_name
  security_group_id  = module.security_groups.redis_sg_id
  kms_key_arn        = module.kms.app_key_arn
  multi_az_enabled   = local.config.enable_multi_az_redis
  sns_topic_arn      = module.monitoring.sns_topic_arn
}

# ─── 12. WAF v2 (CloudFront scope — must use us-east-1 provider) ────────────

module "waf" {
  source = "./modules/waf"
  count  = local.config.enable_waf ? 1 : 0

  providers = {
    aws = aws.us_east_1
  }

  name_prefix = local.name_prefix
  scope       = "CLOUDFRONT"
  rate_limit  = 2000
}

# ─── 13. CloudFront CDN ──────────────────────────────────────────────────────

module "cloudfront" {
  source = "./modules/cloudfront"

  name_prefix     = local.name_prefix
  alb_dns_name    = module.alb.alb_dns_name
  certificate_arn = module.acm.cloudfront_certificate_arn
  domain_aliases  = [var.domain_name, "www.${var.domain_name}"]
  waf_acl_arn     = local.config.enable_waf ? module.waf[0].web_acl_arn : ""
}

# ─── 14. Bastion Host ────────────────────────────────────────────────────────

module "bastion" {
  source = "./modules/bastion"
  count  = var.enable_bastion ? 1 : 0

  name_prefix           = local.name_prefix
  instance_type         = local.config.bastion_instance_type
  subnet_id             = module.vpc.public_subnet_ids[0]
  security_group_id     = module.security_groups.bastion_sg_id
  instance_profile_name = module.iam.bastion_instance_profile_name
  kms_key_arn           = module.kms.app_key_arn
}

# ─── 15. Monitoring — CloudWatch, CloudTrail, SNS ────────────────────────────

module "monitoring" {
  source = "./modules/monitoring"

  name_prefix             = local.name_prefix
  alert_email             = var.alert_email
  kms_key_id              = module.kms.logs_key_id
  kms_key_arn             = module.kms.logs_key_arn
  cloudtrail_bucket_name  = module.s3.cloudtrail_bucket_name
  cloudtrail_role_arn     = module.iam.cloudtrail_role_arn
  ecs_cluster_name        = module.ecs.cluster_name
  ecs_service_name        = module.ecs.service_name
  rds_cluster_id          = module.rds.cluster_id
  alb_arn_suffix          = module.alb.alb_arn
  target_group_arn_suffix = module.alb.target_group_arn
}
