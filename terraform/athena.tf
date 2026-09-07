# =============================================================================
# Analytics Layer: AWS Glue Data Catalog & Amazon Athena
# =============================================================================
# Enables serverless SQL queries on portfolio financial data stored in S3.
#
# Why Athena + Glue?
# In Private Equity, financial analysts need to query ingested ERP and financial
# datasets with standard SQL without provisioning or managing expensive databases.
# =============================================================================

# --- S3 Bucket for Athena Query Results ---
module "athena_results_bucket" {
  source = "./modules/s3-bucket"

  bucket_name      = "${var.project_name}-${var.client_name}-athena-results-${data.aws_caller_identity.current.account_id}"
  purpose          = "athena-query-results"
  enable_lifecycle = true
  expiration_days  = 90 # Transition 30d (Standard-IA), 60d (Glacier), Expire 90d
}

# --- AWS Glue Data Catalog Database ---
resource "aws_glue_catalog_database" "financial_db" {
  name        = "project_apex_financial_db"
  description = "Glue Catalog database for Project Apex portfolio financial analytics"
}

# --- AWS Glue Data Catalog Table (Financial Records) ---
resource "aws_glue_catalog_table" "financial_data" {
  name          = "financial_records"
  database_name = aws_glue_catalog_database.financial_db.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "classification"         = "csv"
    "skip.header.line.count" = "1"
  }

  storage_descriptor {
    location      = "s3://${module.processed_data_bucket.bucket_id}/processed/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "csv-serde"
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
      parameters = {
        "field.delim"            = ","
        "serialization.format"   = ","
      }
    }

    # Columns matching our financial ingestion schema
    columns {
      name = "transaction_id"
      type = "string"
    }
    columns {
      name = "entity"
      type = "string"
    }
    columns {
      name = "revenue"
      type = "double"
    }
    columns {
      name = "expenses"
      type = "double"
    }
    columns {
      name = "ebitda"
      type = "double"
    }
    columns {
      name = "reporting_period"
      type = "string"
    }
  }
}

# --- Amazon Athena Workgroup ---
resource "aws_athena_workgroup" "analytics" {
  name        = "${var.project_name}-analytics-workgroup"
  description = "Dedicated workgroup for Project Apex financial analysts"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${module.athena_results_bucket.bucket_id}/queries/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }

  tags = {
    Name = "${var.project_name}-analytics-workgroup"
  }
}

# --- AWS Glue Data Catalog Table (Operational / Supply Chain Data) ---
# Summit Ridge Logistics: shipment tracking and supply chain KPIs
# queryable via the same Athena workgroup as financial data
resource "aws_glue_catalog_table" "operational_data" {
  name          = "operational_records"
  database_name = aws_glue_catalog_database.financial_db.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "classification"         = "csv"
    "skip.header.line.count" = "1"
  }

  storage_descriptor {
    location      = "s3://${module.summit_ridge_processed_data_bucket.bucket_id}/processed/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "csv-serde"
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
      parameters = {
        "field.delim"          = ","
        "serialization.format" = ","
      }
    }

    columns {
      name = "shipment_id"
      type = "string"
    }
    columns {
      name = "origin"
      type = "string"
    }
    columns {
      name = "destination"
      type = "string"
    }
    columns {
      name = "cost_per_unit"
      type = "double"
    }
    columns {
      name = "on_time_rate"
      type = "double"
    }
    columns {
      name = "reporting_period"
      type = "string"
    }
  }
}

