# =============================================================================
# Input Variables
# =============================================================================
# All configurable values are defined here — never hardcoded in resource blocks.
# This makes the infrastructure reusable across different clients, environments,
# and regions without modifying the core Terraform code.
# =============================================================================

variable "project_name" {
  description = "Name of the project — used in resource naming and tagging"
  type        = string
  default     = "project-apex"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod) — auto title-cased in tags"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-2"
}

variable "client_name" {
  description = "Name of the portfolio company (for tagging and bucket naming)"
  type        = string
  default     = "prestige-industrial"
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications (leave empty to skip)"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}
