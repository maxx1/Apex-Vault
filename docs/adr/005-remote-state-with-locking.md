# ADR 005: Remote State with DynamoDB Locking

**Status:** Accepted  
**Date:** 2026-09-04

## Context

Terraform tracks what infrastructure it created in a **state file** (`terraform.tfstate`). This file is critical — without it, Terraform doesn't know what resources exist.

In a team environment, multiple engineers (or CI/CD pipelines) may run Terraform simultaneously. If two people run `terraform apply` at the same time with local state files, they can corrupt the state or create duplicate resources.

## Decision

**Use S3 for remote state storage** with **DynamoDB for state locking**.

## How It Works

```
Engineer A runs terraform plan
  → Terraform acquires lock in DynamoDB
  → Reads state from S3
  → Calculates changes
  → Releases lock

Engineer B runs terraform apply (at the same time)
  → Terraform tries to acquire lock
  → Lock is held by Engineer A
  → Terraform waits (or fails) instead of corrupting state
```

## Configuration

```hcl
backend "s3" {
  bucket         = "project-apex-tfstate"
  key            = "terraform.tfstate"
  region         = "us-east-2"
  dynamodb_table = "project-apex-tflock"
  encrypt        = true
}
```

| Component | Resource | Purpose |
|---|---|---|
| **S3 bucket** | `project-apex-tfstate` | Centralized, versioned state storage |
| **S3 encryption** | AES256 | Data protection at rest |
| **DynamoDB table** | `project-apex-tflock` | Prevents concurrent modifications |
| **S3 versioning** | Enabled | Can recover previous state if corrupted |

## Consequences

- **Positive:** Multiple engineers can safely work on the same infrastructure
- **Positive:** CI/CD pipelines won't corrupt state during concurrent runs
- **Positive:** State is backed up with S3 versioning — recoverable if corrupted
- **Trade-off:** Requires bootstrapping the S3 bucket and DynamoDB table before `terraform init`
- **Cost:** ~$0.25/month (DynamoDB on-demand + S3 storage)

## What Happens If You Lose State?

If the state file is lost or corrupted:
1. Terraform doesn't know what resources it manages
2. You'd need to `terraform import` each resource manually
3. This is why S3 versioning is enabled — you can recover a previous state version

## Alternatives Considered

- **Local state** — rejected for team use (no locking, no collaboration)
- **Terraform Cloud** — viable but adds dependency on HashiCorp's hosted service
- **GitLab/GitHub state** — emerging options but less mature than S3 backend
