# ADR 001: Terraform over CloudFormation

**Status:** Accepted  
**Date:** 2026-09-04

## Context

We need an Infrastructure as Code (IaC) tool to provision and manage cloud resources for PE portfolio companies. The client portfolio spans **both AWS and Azure** environments.

Key requirements:
- Must support multi-cloud (AWS today, Azure in the future)
- Must support modular, reusable infrastructure patterns
- Must integrate with CI/CD pipelines (GitHub Actions)
- Team members should be able to collaborate safely on shared infrastructure

## Decision

**Use Terraform** (HashiCorp Configuration Language) as the primary IaC tool.

## Rationale

| Factor | Terraform | CloudFormation |
|---|---|---|
| **Multi-cloud** | ✅ AWS, Azure, GCP, 1000+ providers | ❌ AWS only |
| **Module ecosystem** | ✅ Terraform Registry, custom modules | ⚠️ Nested stacks (more complex) |
| **State management** | ✅ Remote backends with locking | ✅ Built-in (managed by AWS) |
| **CI/CD integration** | ✅ First-class GitHub Actions support | ⚠️ Requires custom scripting |
| **Learning curve** | ⚠️ HCL syntax + state concepts | ⚠️ YAML/JSON + AWS-specific |

## Consequences

- **Positive:** Infrastructure patterns can be reused across AWS and Azure clients
- **Positive:** Large community, extensive documentation, and Terraform Registry
- **Trade-off:** Terraform state must be managed (we use S3 + DynamoDB locking)
- **Trade-off:** Team must learn HCL syntax (but it's more readable than CloudFormation JSON)

## Alternatives Considered

- **AWS CloudFormation** — rejected because it's AWS-only
- **Pulumi** — promising (uses real programming languages) but smaller ecosystem
- **AWS CDK** — generates CloudFormation, still AWS-locked
