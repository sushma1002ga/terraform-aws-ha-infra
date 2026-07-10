################################################################################
# QA Environment — Medium resources, WAF enabled, moderate security
################################################################################

# General
project_name = "ha-infra"
team_name    = "platform-engineering"
cost_center  = "engineering"

# Regions
primary_region = "us-east-1"
dr_region      = "us-west-2"

# Networking
vpc_cidr             = "10.1.0.0/16"
enable_vpc_flow_logs = true

# Compute
container_image = "nginx:latest"
container_port  = 80

# Database
db_engine_version  = "15.4"
db_name            = "appdb"
db_master_username = "dbadmin"

# DNS (removed — using ALB DNS directly)

# Security
allowed_bastion_cidrs      = ["10.0.0.0/8"] # Internal only
enable_deletion_protection = true

# Monitoring
alert_email = "qa-alerts@example.com"

# Feature Flags
enable_dr_region = false
enable_bastion   = true
