# ADR 006: Infracost for Client Cost Visibility

**Status:** Accepted  
**Date:** 2026-09-04

## Context

Private equity portfolio companies are cost-conscious. Every dollar of cloud infrastructure spend needs justification. Surprise AWS bills erode trust between the consulting team and the client.

Engineers making infrastructure changes often don't know the cost implications until the monthly bill arrives.

## Decision

**Integrate Infracost into the GitHub Actions CI pipeline** so that every Pull Request automatically shows the estimated monthly cost of the proposed infrastructure changes.

## How It Works

```
Engineer opens PR with Terraform changes
  → GitHub Actions runs Infracost
  → Infracost analyzes the Terraform plan
  → Posts a cost breakdown as a PR comment:
      "This change will add $3.50/month to the infrastructure bill"
  → Team reviews cost impact BEFORE merging
```

## Why This Matters for PE Consulting

| Scenario | Without Infracost | With Infracost |
|---|---|---|
| Engineer adds NAT Gateway | Surprise $32/month on next bill | PR comment shows +$32/month — team decides if it's worth it |
| Scaling to larger instances | Unknown cost until invoice | Exact cost delta visible before merge |
| Client asks "why did our bill go up?" | Manual investigation | Link to the PR that caused the increase |

## Consequences

- **Positive:** No surprise cloud bills — cost is visible before deployment
- **Positive:** Engineers develop cost awareness naturally
- **Positive:** Builds trust with PE clients — transparent infrastructure spending
- **Positive:** PR comments create an audit trail of cost decisions
- **Trade-off:** Requires free Infracost API key (generous free tier)
- **Trade-off:** Cost estimates are approximate (based on list prices, not negotiated rates)

## Implementation

Infracost runs in `.github/workflows/plan.yml`:
1. Analyzes the Terraform plan output
2. Generates a JSON cost breakdown
3. Posts the estimate as a GitHub PR comment
4. Updates the comment on subsequent pushes to the same PR

## Estimated Project Cost

| Resource | Monthly Cost |
|---|---|
| S3 (2 buckets, minimal storage) | ~$0.50 |
| Lambda (free tier) | ~$0.00 |
| CloudWatch (dashboard + logs) | ~$3.00 |
| SNS (alerts) | ~$0.00 |
| DynamoDB (state lock) | ~$0.25 |
| VPC (no NAT Gateway) | ~$0.00 |
| **Total** | **~$3.75/month** |
