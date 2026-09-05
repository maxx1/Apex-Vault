# ADR 004: GitHub Actions with OIDC Authentication

**Status:** Accepted  
**Date:** 2026-09-04

## Context

GitHub Actions needs AWS access to run `terraform plan` (on PRs) and `terraform apply` (on merge to main). There are two main approaches:

1. **Static credentials** — store AWS access key + secret key in GitHub Secrets
2. **OIDC federation** — GitHub Actions assumes an IAM role using a short-lived token

## Decision

**Use OIDC (OpenID Connect) federation** — GitHub Actions authenticates with AWS using short-lived tokens, not static credentials.

## How It Works

```
GitHub Actions → requests token from GitHub OIDC provider
                → presents token to AWS STS (Security Token Service)
                → AWS verifies the token against the OIDC provider
                → AWS issues temporary credentials (15 min - 1 hour)
                → GitHub Actions uses temporary credentials to run Terraform
```

## Rationale

| Factor | OIDC | Static Credentials |
|---|---|---|
| **Credential lifetime** | Minutes (auto-expires) | Permanent until rotated |
| **Rotation needed** | No (automatic) | Yes (manual process) |
| **Leak risk** | Low (short-lived, auto-expire) | High (permanent if leaked) |
| **Setup complexity** | Moderate (one-time IAM config) | Simple (copy/paste keys) |
| **Audit trail** | Each run has unique credentials | Shared credentials across runs |

## Consequences

- **Positive:** No long-lived credentials stored anywhere — eliminates an entire class of security risk
- **Positive:** Each GitHub Actions run gets unique temporary credentials — better audit trail
- **Positive:** No manual credential rotation process needed
- **Trade-off:** One-time setup of IAM OIDC provider and trust policy (handled by Terraform in `iam.tf`)

## Why This Matters for PE

Private equity portfolio companies handle sensitive financial data. Static AWS credentials in a GitHub repository (even encrypted as Secrets) are a risk that's easy to avoid with OIDC. When presenting infrastructure to a PE client's security team, OIDC demonstrates mature security practices.

## Implementation

The OIDC provider and IAM role are created in `terraform/iam.tf`:
- `aws_iam_openid_connect_provider.github` — registers GitHub as a trusted identity provider
- `aws_iam_role.github_actions` — the role that GitHub Actions assumes
- Trust policy restricts access to the specific repository
