################################################################################
# Dev Environment — Minimal resources, single-region, cost-optimized
################################################################################

# General
project_name = "ha-infra"
team_name    = "platform-engineering"
cost_center  = "engineering"

# Regions
primary_region = "us-east-1"
dr_region      = "us-west-2"

# Networking
vpc_cidr             = "10.0.0.0/16"
enable_vpc_flow_logs = true

# Compute
container_image = "nginx:latest"
container_port  = 80

# Database
db_engine_version  = "15.8"
db_name            = "appdb"
db_master_username = "dbadmin"

# DNS
domain_name     = "sidsdestination.shop"
create_dns_zone = true

# Security
allowed_bastion_cidrs      = ["0.0.0.0/0"] # Restrict in real environments!
enable_deletion_protection = false

# Monitoring
alert_email = "ksiddharth263@gmail.com"

# Feature Flags
enable_dr_region = false
enable_waf       = false
enable_bastion   = true
