# =============================================================================
# Lambda Data Processor
# =============================================================================
# Event-driven data processing function triggered by S3 uploads.
# When a file lands in the raw data bucket, Lambda:
# 1. Validates the file (type, size, format)
# 2. Adds processing metadata (timestamp, status)
# 3. Copies the validated file to the processed data bucket
# 4. Logs all activity to CloudWatch
#
# Design Decision: Lambda over AWS Glue for this use case.
# Lambda is near-zero cost, event-driven, and fast.
# See: docs/adr/003-lambda-over-glue-for-processing.md
# =============================================================================

# --- Package the Lambda code ---
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/processor"
  output_path = "${path.module}/../lambda/processor.zip"
}

# --- Lambda Function ---
resource "aws_lambda_function" "data_processor" {
  function_name    = "${var.project_name}-${var.environment}-processor"
  description      = "Validates and processes raw data uploads from portfolio company"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      PROCESSED_BUCKET = module.processed_data_bucket.bucket_id
      ENVIRONMENT      = var.environment
      PROJECT_NAME     = var.project_name
      CLIENT_NAME      = var.client_name
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-processor"
  }
}

# --- Allow S3 to invoke Lambda ---
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = module.raw_data_bucket.bucket_arn
}
