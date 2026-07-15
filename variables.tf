################################################################################
# Root Variables
################################################################################

# ─── General ──────────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Name of the project, used as prefix for all resources"
  type        = string
  default     = "ha-infra"
}

variable "team_name" {
  description = "Team responsible for this infrastructure"
  type        = string
  default     = "platform-engineering"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "engineering"
}

# ─── Regions ──────────────────────────────────────────────────────────────────

variable "primary_region" {
  description = "Primary AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "dr_region" {
  description = "Disaster Recovery AWS region"
  type        = string
  default     = "us-west-2"
}

# ─── Networking ───────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

# ─── Compute ──────────────────────────────────────────────────────────────────

variable "container_image" {
  description = "Docker image for ECS tasks"
  type        = string
  default     = "nginx:latest"
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 80
}

# ─── Database ─────────────────────────────────────────────────────────────────

variable "db_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "15.8"
}

variable "db_name" {
  description = "Name of the default database"
  type        = string
  default     = "appdb"
}

variable "db_master_username" {
  description = "Master username for the RDS cluster"
  type        = string
  default     = "dbadmin"
  sensitive   = true
}

# ─── DNS & Domain ────────────────────────────────────────────────────────────

variable "domain_name" {
  description = "Root domain name for Route53 and certificates"
  type        = string
  default     = "sidsdestination.shop"
}

variable "create_dns_zone" {
  description = "Whether to create a new Route53 hosted zone"
  type        = bool
  default     = true
}

# ─── Security ─────────────────────────────────────────────────────────────────

variable "allowed_bastion_cidrs" {
  description = "CIDR blocks allowed to access the bastion host"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production!
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for critical resources"
  type        = bool
  default     = false
}

# ─── Monitoring ───────────────────────────────────────────────────────────────

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
  default     = "alerts@example.com"
}

# ─── Feature Flags (overridden per environment) ──────────────────────────────

variable "enable_dr_region" {
  description = "Enable DR region resources (cross-region replication, standby)"
  type        = bool
  default     = false
}

variable "enable_waf" {
  description = "Enable WAF on CloudFront"
  type        = bool
  default     = true
}

variable "enable_bastion" {
  description = "Enable bastion host"
  type        = bool
  default     = true
}
