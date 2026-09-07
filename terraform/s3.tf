# =============================================================================
# S3 Data Buckets
# =============================================================================
# Two buckets using our reusable module:
# 1. Raw Data Bucket — where the portfolio company uploads source files
# 2. Processed Data Bucket — where validated, transformed data lands
#
# Design Decision: Using a reusable module instead of copy-pasting bucket
# configurations. Both buckets get the same security baseline (encryption,
# versioning, public access blocked) but with different lifecycle settings.
# See: docs/adr/002-s3-for-raw-data-storage.md
# =============================================================================

# --- Raw Data Bucket ---
# Client uploads go here. Lambda is triggered on every new object.
module "raw_data_bucket" {
  source = "./modules/s3-bucket"

  bucket_name        = "${var.project_name}-${var.client_name}-raw-${data.aws_caller_identity.current.account_id}"
  purpose            = "raw-data-ingestion"
  versioning_enabled = true
  enable_lifecycle   = true
  expiration_days    = 90  # Raw data expires after 90 days
  force_destroy      = true
}

# --- Processed Data Bucket ---
# Clean, validated data lands here. Analysts have read-only access.
module "processed_data_bucket" {
  source = "./modules/s3-bucket"

  bucket_name        = "${var.project_name}-${var.client_name}-processed-${data.aws_caller_identity.current.account_id}"
  purpose            = "processed-data-warehouse"
  versioning_enabled = true
  enable_lifecycle   = true
  expiration_days    = 365  # Keep processed data longer than raw
  force_destroy      = true
}

# --- S3 Event Notification ---
# Triggers Lambda when a new file is uploaded to the raw data bucket
resource "aws_s3_bucket_notification" "raw_data_trigger" {
  bucket = module.raw_data_bucket.bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.data_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

# ─── CLEARWATER HEALTH PARTNERS (Portfolio Company #2) ────────────────────
# PE-backed healthcare staffing firm. Demonstrates multi-tenant scalability:
# onboarding a new acquisition takes only 2 module calls.

module "clearwater_raw_data_bucket" {
  source = "./modules/s3-bucket"

  bucket_name        = "${var.project_name}-clearwater-health-raw-${data.aws_caller_identity.current.account_id}"
  purpose            = "raw-data-ingestion"
  versioning_enabled = true
  enable_lifecycle   = true
  expiration_days    = 90
  force_destroy      = true
}

module "clearwater_processed_data_bucket" {
  source = "./modules/s3-bucket"

  bucket_name        = "${var.project_name}-clearwater-health-processed-${data.aws_caller_identity.current.account_id}"
  purpose            = "processed-data-warehouse"
  versioning_enabled = true
  enable_lifecycle   = true
  expiration_days    = 365
  force_destroy      = true
}

# ─── SUMMIT RIDGE LOGISTICS (Portfolio Company #3) ────────────────────────
# Supply chain / 3PL company. Operational tracking data flows through
# DynamoDB for real-time shipment metrics alongside S3 for batch financials.

module "summit_ridge_raw_data_bucket" {
  source = "./modules/s3-bucket"

  bucket_name        = "${var.project_name}-summit-ridge-raw-${data.aws_caller_identity.current.account_id}"
  purpose            = "raw-data-ingestion"
  versioning_enabled = true
  enable_lifecycle   = true
  expiration_days    = 90
  force_destroy      = true
}

module "summit_ridge_processed_data_bucket" {
  source = "./modules/s3-bucket"

  bucket_name        = "${var.project_name}-summit-ridge-processed-${data.aws_caller_identity.current.account_id}"
  purpose            = "processed-data-warehouse"
  versioning_enabled = true
  enable_lifecycle   = true
  expiration_days    = 365
  force_destroy      = true
}

# ─── MERIDIAN CAPITAL ADVISORS (Portfolio Company #4) ─────────────────────
# Financial advisory firm. Data schema designed for direct loading into
# Snowflake or PostgreSQL as the company scales its analytical maturity.
# S3 serves as the Snowflake-ready staging layer.

module "meridian_raw_data_bucket" {
  source = "./modules/s3-bucket"

  bucket_name        = "${var.project_name}-meridian-capital-raw-${data.aws_caller_identity.current.account_id}"
  purpose            = "raw-data-ingestion"
  versioning_enabled = true
  enable_lifecycle   = true
  expiration_days    = 90
  force_destroy      = true
}

module "meridian_processed_data_bucket" {
  source = "./modules/s3-bucket"

  bucket_name        = "${var.project_name}-meridian-capital-processed-${data.aws_caller_identity.current.account_id}"
  purpose            = "processed-data-warehouse"
  versioning_enabled = true
  enable_lifecycle   = true
  expiration_days    = 365
  force_destroy      = true
}

