################################################################################
# Local Values
################################################################################

locals {
  # Environment derived from Terraform workspace
  environment = terraform.workspace

  # Project naming
  project_name = var.project_name
  name_prefix  = "${var.project_name}-${local.environment}"

  # Common tags applied to ALL resources
  common_tags = {
    Project     = var.project_name
    Environment = local.environment
    ManagedBy   = "terraform"
    Team        = var.team_name
    CostCenter  = var.cost_center
  }

  # Environment-specific configurations
  env_config = {
    dev = {
      nat_gateway_count       = 1
      ecs_desired_count       = 1
      ecs_min_count           = 1
      ecs_max_count           = 2
      ecs_cpu                 = 256
      ecs_memory              = 512
      rds_instance_count      = 1
      rds_instance_class      = "db.t3.medium"
      rds_backup_retention    = 7
      rds_deletion_protection = false
      redis_node_type         = "cache.t3.micro"
      redis_num_cache_nodes   = 1
      enable_dr               = false
      enable_multi_az_redis   = false
      bastion_instance_type   = "t3.micro"
    }
    qa = {
      nat_gateway_count       = 2
      ecs_desired_count       = 2
      ecs_min_count           = 2
      ecs_max_count           = 4
      ecs_cpu                 = 512
      ecs_memory              = 1024
      rds_instance_count      = 2
      rds_instance_class      = "db.t3.large"
      rds_backup_retention    = 14
      rds_deletion_protection = true
      redis_node_type         = "cache.t3.small"
      redis_num_cache_nodes   = 2
      enable_dr               = false
      enable_waf              = true
      enable_multi_az_redis   = false
      bastion_instance_type   = "t3.micro"
    }
    prod = {
      nat_gateway_count       = 3
      ecs_desired_count       = 3
      ecs_min_count           = 3
      ecs_max_count           = 10
      ecs_cpu                 = 1024
      ecs_memory              = 2048
      rds_instance_count      = 3
      rds_instance_class      = "db.r6g.large"
      rds_backup_retention    = 35
      rds_deletion_protection = true
      redis_node_type         = "cache.r6g.large"
      redis_num_cache_nodes   = 3
      enable_dr               = true
      enable_waf              = true
      enable_multi_az_redis   = true
      bastion_instance_type   = "t3.small"
    }
  }

  # Current environment config (with fallback to dev)
  config = lookup(local.env_config, local.environment, local.env_config["dev"])

  # Availability Zones
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

################################################################################
# Data Sources
################################################################################

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
