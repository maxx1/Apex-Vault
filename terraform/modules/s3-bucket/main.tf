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

# --- SSL-Only Bucket Policy (Cloud Security) ---
# Enforces TLS/HTTPS for all requests — denies any unencrypted HTTP access.
# Required for financial data compliance (SOC2, SEC) and flagged by Infracost
# cloud security policies if missing.
resource "aws_s3_bucket_policy" "ssl_only" {
  bucket = aws_s3_bucket.this.id

  # Ensure public access block is applied before the policy
  depends_on = [aws_s3_bucket_public_access_block.this]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.this.arn,
          "${aws_s3_bucket.this.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# --- Lifecycle Policy (Cost Optimization) ---
# Three rules for enterprise-grade cost governance:
# 1. Abort incomplete multipart uploads after 7 days (prevents orphaned storage costs)
# 2. Transition noncurrent versions to cheaper storage before deletion
# 3. Standard tiering: Standard → Standard-IA (30d) → Glacier (60d) → Delete
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = var.enable_lifecycle ? 1 : 0
  bucket = aws_s3_bucket.this.id

  # Rule 1: Abort incomplete multipart uploads
  # Large file uploads that fail mid-transfer leave orphaned parts that
  # silently accumulate storage costs. This rule cleans them up automatically.
  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Rule 2: Transition noncurrent object versions to cheaper storage
  # When versioning is enabled, old versions pile up at full price.
  # This moves them to Standard-IA after 30 days and Glacier after 90 days
  # before final cleanup — saving 40-80% on storage costs.
  rule {
    id     = "noncurrent-version-optimization"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 180
    }
  }

  # Rule 3: Current object lifecycle tiering
  rule {
    id     = "cost-optimization"
    status = "Enabled"

    filter {}

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
