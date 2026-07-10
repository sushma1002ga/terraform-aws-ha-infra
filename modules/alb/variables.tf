variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of public subnets for the ALB"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for the ALB"
  type        = string
}

variable "container_port" {
  description = "Port the application listens on"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Health check path for the target group"
  type        = string
  default     = "/health"
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "enable_access_logs" {
  description = "Enable ALB access logs to S3"
  type        = bool
  default     = true
}

variable "access_logs_bucket" {
  description = "S3 bucket for ALB access logs"
  type        = string
  default     = ""
}
