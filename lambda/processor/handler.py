"""
PE Data Landing Zone — Data Processor Lambda

Triggered by S3 ObjectCreated events on the raw data bucket.
Validates uploaded files, adds processing metadata, and copies
them to the processed data bucket.

Architecture Decision: Lambda over AWS Glue
- Near-zero cost (pay per invocation, not per hour)
- Event-driven (processes files as they arrive)
- Fast startup (no Glue crawler warm-up)
- Sufficient for file validation and transfer
- See: docs/adr/003-lambda-over-glue-for-processing.md
"""

import json
import os
import logging
import urllib.parse
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

# --- Configuration ---
logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client("s3")

PROCESSED_BUCKET = os.environ.get("PROCESSED_BUCKET", "")
ENVIRONMENT = os.environ.get("ENVIRONMENT", "dev")
PROJECT_NAME = os.environ.get("PROJECT_NAME", "project-apex")
CLIENT_NAME = os.environ.get("CLIENT_NAME", "unknown")

# Allowed file types for ingestion
ALLOWED_EXTENSIONS = {".csv", ".json", ".xlsx", ".parquet"}
MAX_FILE_SIZE_MB = 500


def lambda_handler(event, context):
    """
    Main handler — processes S3 event notifications.

    Args:
        event: S3 event notification (contains bucket name, object key)
        context: Lambda runtime context (request ID, remaining time, etc.)

    Returns:
        dict: Processing result with status and metadata
    """
    logger.info("Event received: %s", json.dumps(event, indent=2))

    results = []

    for record in event.get("Records", []):
        try:
            result = process_record(record)
            results.append(result)
        except Exception as e:
            logger.error("Failed to process record: %s", str(e))
            results.append({
                "status": "error",
                "error": str(e),
                "record": record.get("s3", {}).get("object", {}).get("key", "unknown"),
            })

    # Summary
    success_count = sum(1 for r in results if r["status"] == "success")
    error_count = sum(1 for r in results if r["status"] == "error")

    summary = {
        "total_records": len(results),
        "successful": success_count,
        "errors": error_count,
        "results": results,
    }

    logger.info("Processing complete: %s", json.dumps(summary, indent=2))
    return summary


def process_record(record):
    """
    Process a single S3 event record.

    Steps:
    1. Extract bucket/key from the event
    2. Validate file type and size
    3. Copy to processed bucket with metadata tags
    """
    # Extract S3 info from the event
    source_bucket = record["s3"]["bucket"]["name"]
    source_key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])
    file_size = record["s3"]["object"].get("size", 0)

    logger.info(
        "Processing file: s3://%s/%s (size: %d bytes)",
        source_bucket,
        source_key,
        file_size,
    )

    # --- Validation ---
    validation = validate_file(source_key, file_size)
    if not validation["valid"]:
        logger.warning("Validation failed for %s: %s", source_key, validation["reason"])
        return {
            "status": "error",
            "source_key": source_key,
            "error": f"Validation failed: {validation['reason']}",
        }

    # --- Build destination path ---
    # Organize processed data by date: processed/YYYY/MM/DD/filename
    now = datetime.now(timezone.utc)
    date_prefix = now.strftime("%Y/%m/%d")
    filename = source_key.split("/")[-1]
    dest_key = f"processed/{date_prefix}/{filename}"

    # --- Copy to processed bucket with metadata tags ---
    try:
        s3_client.copy_object(
            CopySource={"Bucket": source_bucket, "Key": source_key},
            Bucket=PROCESSED_BUCKET,
            Key=dest_key,
            Tagging=urllib.parse.urlencode({
                "processing_status": "validated",
                "processed_at": now.isoformat(),
                "source_bucket": source_bucket,
                "source_key": source_key,
                "client": CLIENT_NAME,
                "environment": ENVIRONMENT,
            }),
            TaggingDirective="REPLACE",
            ServerSideEncryption="AES256",
        )

        logger.info(
            "Successfully processed: s3://%s/%s -> s3://%s/%s",
            source_bucket,
            source_key,
            PROCESSED_BUCKET,
            dest_key,
        )

        return {
            "status": "success",
            "source": f"s3://{source_bucket}/{source_key}",
            "destination": f"s3://{PROCESSED_BUCKET}/{dest_key}",
            "file_size_bytes": file_size,
            "processed_at": now.isoformat(),
        }

    except ClientError as e:
        logger.error("S3 copy failed: %s", str(e))
        raise


def validate_file(key, size_bytes):
    """
    Validate file type and size before processing.

    Returns:
        dict: {"valid": bool, "reason": str}
    """
    # Check file extension
    extension = os.path.splitext(key)[1].lower()
    if extension not in ALLOWED_EXTENSIONS:
        return {
            "valid": False,
            "reason": f"File type '{extension}' not allowed. Accepted: {ALLOWED_EXTENSIONS}",
        }

    # Check file size
    max_bytes = MAX_FILE_SIZE_MB * 1024 * 1024
    if size_bytes > max_bytes:
        return {
            "valid": False,
            "reason": f"File size ({size_bytes} bytes) exceeds limit ({max_bytes} bytes)",
        }

    # Check for empty files
    if size_bytes == 0:
        return {
            "valid": False,
            "reason": "Empty file — nothing to process",
        }

    return {"valid": True, "reason": "OK"}
