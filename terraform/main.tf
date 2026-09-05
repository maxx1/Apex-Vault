# =============================================================================
# Terraform Configuration
# =============================================================================
# Provider: AWS (us-east-2)
# Backend: S3 + DynamoDB for remote state with locking
#
# Why S3 backend? In a team environment, local state files cause conflicts.
# Remote state with DynamoDB locking prevents concurrent modifications.
# See: docs/adr/005-remote-state-with-locking.md
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  # Remote state — created during bootstrap (see README.md)
  backend "s3" {
    bucket         = "project-apex-tfstate"
    key            = "terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "project-apex-tflock"
    encrypt        = true
  }
}

# --- AWS Provider ---
provider "aws" {
  region = var.aws_region

  # Default tags applied to EVERY resource — consistent tagging strategy
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Client      = var.client_name
    }
  }
}

# --- Data Sources ---
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
