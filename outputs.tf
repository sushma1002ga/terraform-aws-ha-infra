################################################################################
# Root Outputs
################################################################################

# ─── VPC ──────────────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "ID of the primary VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

# ─── Load Balancer ────────────────────────────────────────────────────────────

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.alb_arn
}

# ─── ECS ──────────────────────────────────────────────────────────────────────

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs.service_name
}

# ─── Database ─────────────────────────────────────────────────────────────────

output "rds_cluster_endpoint" {
  description = "Writer endpoint of the Aurora cluster"
  value       = module.rds.cluster_endpoint
  sensitive   = true
}

output "rds_reader_endpoint" {
  description = "Reader endpoint of the Aurora cluster"
  value       = module.rds.reader_endpoint
  sensitive   = true
}

# ─── ElastiCache ──────────────────────────────────────────────────────────────

output "redis_endpoint" {
  description = "Primary endpoint of the Redis cluster"
  value       = module.elasticache.primary_endpoint
  sensitive   = true
}

# ─── S3 ───────────────────────────────────────────────────────────────────────

output "app_bucket_name" {
  description = "Name of the application S3 bucket"
  value       = module.s3.app_bucket_name
}

# ─── CloudFront (removed — using ALB directly) ──────────────────────────────

# ─── Route53 (removed — no domain) ───────────────────────────────────────────



# ─── Monitoring ───────────────────────────────────────────────────────────────

output "sns_topic_arn" {
  description = "ARN of the SNS alerts topic"
  value       = module.monitoring.sns_topic_arn
}

# ─── Environment Info ─────────────────────────────────────────────────────────

output "environment" {
  description = "Current environment name"
  value       = local.environment
}

output "primary_region" {
  description = "Primary AWS region"
  value       = var.primary_region
}

# ─── ECR ──────────────────────────────────────────────────────────────────────

output "ecr_repository_url" {
  description = "ECR repository URL for banking app"
  value       = module.ecr.repository_url
}
