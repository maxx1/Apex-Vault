# =============================================================================
# DynamoDB: Operational Data Store
# =============================================================================
# Real-time operational tracking for portfolio companies with high-velocity
# data patterns. Summit Ridge Logistics uses this for shipment tracking,
# delivery metrics, and supply chain KPIs that need sub-millisecond reads.
#
# Design Decision: DynamoDB over RDS for operational data.
# Financial batch data goes through S3/Athena. Operational data that
# changes frequently (shipment status, inventory levels) needs a purpose
# built database with consistent single-digit millisecond performance.
# Pay-per-request billing keeps costs at $0 when idle.
# =============================================================================

resource "aws_dynamodb_table" "operational_data" {
  name         = "${var.project_name}-${var.environment}-operational-data"
  billing_mode = "PAY_PER_REQUEST" # $0 when idle, scales automatically
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S" # e.g., COMPANY#summit-ridge
  }

  attribute {
    name = "SK"
    type = "S" # e.g., SHIPMENT#2026-09-06 or METRIC#on-time-rate
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-operational-data"
    Purpose     = "real-time-operational-tracking"
    Environment = var.environment
  }
}
