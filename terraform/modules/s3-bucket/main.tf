# =============================================================================
# Reusable S3 Bucket Module
# =============================================================================
# This module creates a standardized, secure S3 bucket with:
# - Server-side encryption (AES256)
# - Versioning (configurable)
# - Public access blocked (always)
# - Lifecycle policies for cost optimization (configurable)
#
# Why a module? DRY principle — we use this module twice:
# 1. Raw data bucket (where clients upload files)
# 2. Processed data bucket (where clean data lands)
# Same security baseline, different lifecycle configurations.
# =============================================================================

resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name    = var.bucket_name
    Purpose = var.purpose
  })
}

# --- Versioning ---
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# --- Server-Side Encryption (AES256) ---
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# --- Block ALL Public Access ---
# This is non-negotiable for financial data. No exceptions.
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Lifecycle Policy (Cost Optimization) ---
# Automatically transitions data to cheaper storage tiers over time.
# Standard → Standard-IA (30 days) → Glacier (60 days) → Delete
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = var.enable_lifecycle ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "cost-optimization"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }

    expiration {
      days = var.expiration_days
    }
  }
}
