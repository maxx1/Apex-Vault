# ADR 002: S3 for Raw Data Storage

**Status:** Accepted  
**Date:** 2026-09-04

## Context

Portfolio companies need to upload financial data files (CSV, JSON, Excel, Parquet) to a secure location. The storage solution must:

- Encrypt data at rest (financial/regulatory requirement)
- Maintain file versions (audit trail)
- Optimize costs over time (lifecycle policies)
- Block all public access (non-negotiable for financial data)

## Decision

**Use Amazon S3** with a reusable Terraform module that enforces security and cost optimization by default.

## Configuration

| Setting | Value | Why |
|---|---|---|
| **Encryption** | AES256 (server-side) | Protects financial data at rest |
| **Versioning** | Enabled | Audit trail — never lose a file version |
| **Public access** | Blocked (all 4 settings) | Financial data must never be publicly accessible |
| **Lifecycle: Standard → IA** | 30 days | Reduce costs for infrequently accessed files |
| **Lifecycle: IA → Glacier** | 60 days | Archive old data at ~$0.004/GB/month |
| **Lifecycle: Delete** | 90 days (raw) / 365 days (processed) | Processed data retained longer for analysis |

## Consequences

- **Positive:** Near-zero cost for small volumes (S3 Standard is $0.023/GB/month)
- **Positive:** Lifecycle policies automatically reduce costs over time
- **Positive:** Versioning provides complete audit trail
- **Trade-off:** Glacier retrieval takes minutes-to-hours (acceptable for archived data)

## Alternatives Considered

- **EBS volumes** — rejected (not designed for object storage, no lifecycle policies)
- **EFS** — rejected (overkill for file uploads, more expensive)
- **Snowflake staging** — rejected (adds complexity; S3 is the standard staging area for Snowflake ingestion anyway)
