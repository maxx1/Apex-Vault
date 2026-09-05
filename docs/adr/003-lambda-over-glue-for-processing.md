# ADR 003: Lambda over AWS Glue for Data Processing

**Status:** Accepted  
**Date:** 2026-09-04

## Context

We need a compute service to process files when they land in the raw data S3 bucket. The processing logic is:
1. Validate file type and size
2. Add processing metadata (timestamp, status)
3. Copy validated file to the processed data bucket

This is **file validation and transfer**, not complex ETL transformation.

## Decision

**Use AWS Lambda** (Python 3.12, event-driven, triggered by S3 events).

## Rationale

| Factor | Lambda | AWS Glue |
|---|---|---|
| **Cost** | ~$0.00/month (free tier covers this) | $0.44/DPU-hour (minimum 2 DPUs) |
| **Startup time** | Milliseconds (warm) | 1-2 minutes (crawler + job startup) |
| **Trigger** | Native S3 event integration | Requires EventBridge or scheduled crawl |
| **Complexity** | Simple Python function | PySpark jobs, crawlers, catalogs |
| **Right fit** | File validation, simple transforms | Complex joins, schema inference, Spark-scale ETL |

## Consequences

- **Positive:** Near-zero cost — we only pay when files are processed
- **Positive:** Files are processed within seconds of upload (event-driven)
- **Positive:** Simple Python code that any engineer can understand and maintain
- **Trade-off:** Lambda has a 15-minute timeout and 10GB memory limit
- **Upgrade path:** If processing grows to need schema inference, complex joins, or Spark-based transformations → migrate to AWS Glue or Step Functions

## When to Upgrade

Migrate to AWS Glue or Step Functions when:
- File transformation requires joins across multiple data sources
- Processing time exceeds 15 minutes per file
- Data volume requires parallel Spark processing
- Schema inference or data cataloging is needed
