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

# --- BAKER LOGISTICS (Portfolio Company #2)
------------
# Demonstrates multi-tenant scalability:
# Onboarding a new aquisition
# takes only 2 module calss instead of rewriting infrastructure

module "baker_raw_data_bucket? {
  sources = "./modules/s3-bucket"

  bucket_name = "${var.project_name}-baker-logistics-raw-${data.aws_caller_identity.current.account_id}"
  purpose     = "raw-data-ingestion"
  versioning_enabled = true
  enable_lifecycle = true
  expiration_days = 90 # Raw data expires after 90 days
  force_destroy = true
}

module "baker_processed_data_bucket" {
  sources = "./modules/s3-bucket"

  bucket_name = "${var.project_name}-baker-logistics-processed-${data.aws_caller_identity.current.account_id}"
  purpose     = "processed-data-warehouse"
  versioning_enabled = true
  enable_lifecycle = true
  expiration_days = 365  # Keep processed data longer than raw
  force_destroy = true
} 

