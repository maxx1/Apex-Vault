# Rehearsal Guide — Apex Vault

Personal talking points for explaining the infrastructure decisions. Focus: **why** each tool was chosen and **how** it works, explained simply.

---

## AWS — Why These Services

### S3 (Storage)

**What it is:** Object storage for files — think of it as a cloud hard drive that never runs out of space.

**Why I chose it:**
- Cheapest durable storage in AWS — 11 nines of durability (99.999999999%)
- Every file is encrypted at rest with AES-256
- Versioning keeps a history of every file change — if someone uploads a bad file, you can roll back
- Lifecycle rules automatically move old data to cheaper storage tiers, then delete it. Standard → Standard-IA (30 days) → Glacier (60 days) → Delete. This saves 40-80% on storage costs without anyone touching it

**How I used it:**
- 10 buckets total — each portfolio company gets a raw bucket (where data lands) and a processed bucket (where validated data goes)
- One reusable Terraform module creates all 10. Same security baseline, different names
- SSL-only bucket policy means every request must use HTTPS — no unencrypted access, ever

**Simple explanation:** "S3 is the data lake. All financial data from all portfolio companies lands here. It's encrypted, versioned, and lifecycle-managed so costs stay low automatically."

---

### Lambda (Compute)

**What it is:** Serverless compute — code that runs only when triggered, with no servers to manage.

**Why I chose it:**
- Event-driven: runs only when a file is uploaded. No idle costs
- Near-zero cost at low volumes (free tier covers 1M requests/month)
- Fast: 206ms average processing time
- Right-sized: for file validation and transfer, a full-time server (EC2) or heavy ETL engine (Glue) would be overkill

**How I used it:**
- Python 3.12 function that validates file type (.csv, .json, .xlsx, .parquet), checks size (< 500MB), then copies the file to the processed bucket with metadata tags
- S3 event notification triggers it automatically — no polling, no cron jobs
- Organized output by date: `processed/2026/09/07/filename.csv`

**Simple explanation:** "When a file is uploaded, Lambda automatically validates it and moves it to the right place. No servers running, no monthly cost when nothing's happening."

---

### DynamoDB (NoSQL Database)

**What it is:** A fully managed NoSQL database for data that changes frequently.

**Why I chose it:**
- Sub-millisecond reads — fast enough for real-time dashboards
- PAY_PER_REQUEST billing: $0 when idle, scales automatically under load
- No capacity planning needed — it just works
- Point-in-time recovery for disaster recovery

**How I used it:**
- Operational data store for Summit Ridge Logistics — shipment tracking, delivery metrics, supply chain KPIs
- Partition key / sort key design: `COMPANY#summit-ridge` / `SHIPMENT#2026-09-06`
- Financial batch data goes through S3/Athena. Operational data that changes hourly goes through DynamoDB. Different access patterns → different databases

**Simple explanation:** "For data that changes frequently — like shipment tracking or live inventory — I used DynamoDB. It gives instant reads and costs nothing when idle. Financial data that's updated quarterly goes through the S3 pipeline instead."

---

### Athena + Glue (Analytics)

**What it is:** Serverless SQL engine (Athena) + data catalog (Glue) that lets you query S3 data with standard SQL.

**Why I chose it:**
- No database to provision, manage, or pay for when idle
- Standard SQL — analysts already know it, no new language to learn
- Pay per query, not per hour. Charged by data scanned (~$5 per TB scanned)
- Glue catalog maps raw CSV files to typed SQL tables automatically

**How I used it:**
- Glue catalog has 2 tables: `financial_records` (revenue, expenses, EBITDA) and `operational_records` (shipments, cost per unit, on-time rate)
- Athena workgroup enforces encryption on query results and publishes metrics to CloudWatch
- Analysts run queries like `SELECT entity, SUM(revenue) FROM financial_records GROUP BY entity` directly on S3 data

**Simple explanation:** "Athena lets analysts query the data lake with SQL. No database to manage, no upfront costs. Glue maps the files in S3 to SQL tables so Athena knows the schema."

---

### VPC (Networking)

**What it is:** A logically isolated network within AWS — your own private section of the cloud.

**Why I chose it:**
- Required for any production workload that needs private network access (databases, internal APIs, containers)
- Multi-AZ architecture for high availability (resources spread across 2 physical data centers)
- Demonstrates enterprise networking patterns even though Lambda doesn't technically need it here

**How I used it:**
- `10.0.0.0/16` CIDR block — 65,536 IP addresses
- 2 public subnets (for load balancers, NAT gateways) + 2 private subnets (for databases, application servers)
- No NAT Gateway in dev environment — saves ~$32/month. Would add in production

**Simple explanation:** "The VPC is the network foundation. It's there for future resources like databases or containers that need private network isolation. Right now it costs $0, but it's ready when you need it."

---

### CloudWatch + SNS (Monitoring & Alerting)

**What it is:** AWS's built-in monitoring service (CloudWatch) + notification service (SNS).

**Why I chose it:**
- Native to AWS — no third-party tools to manage
- Dashboard gives real-time visibility into pipeline health
- Alarms catch problems automatically (Lambda errors, throttling)
- SNS sends email alerts when something goes wrong

**How I used it:**
- Dashboard with 6 widgets: Lambda invocations, errors, duration, throttles, DynamoDB reads/writes, DynamoDB latency
- 2 alarms: Lambda errors > 3 in 5 minutes, Lambda throttles > 5 in 5 minutes
- Log group with 7-day retention — enough for debugging, not so long it costs extra

**Simple explanation:** "CloudWatch is the control panel. It shows how many files are being processed, how fast, and if anything's broken. If Lambda starts failing, it sends an email automatically."

---

### IAM (Access Control)

**What it is:** AWS Identity and Access Management — controls who can do what.

**Why I chose it / how I designed it:**
- Least privilege principle: every role gets only the permissions it needs, scoped to specific resources
- No wildcard (*) access except for the GitHub Actions deployment role (which needs broad permissions to manage infrastructure)
- 3 separate roles:
  1. **Lambda execution role:** Read raw bucket, write processed bucket, write CloudWatch logs. That's it
  2. **Client analyst role:** Read-only access to processed data. Cannot access raw data, cannot modify anything
  3. **GitHub Actions OIDC role:** Deploys infrastructure via CI/CD. Uses OIDC federation — no static AWS access keys

**Simple explanation:** "Every component gets exactly the permissions it needs, nothing more. Lambda can read raw data and write processed data. Analysts can only read processed data. GitHub deploys via temporary tokens, not stored passwords."

---

## Terraform — Why Infrastructure as Code

### Why Terraform over clicking in the AWS Console

**The simple answer:** "If I built this in the AWS Console, I'd have no record of what I did. If something breaks, I'd have to remember every setting I clicked. With Terraform, the entire infrastructure is defined in code files, version-controlled in Git, and reproducible. I can `terraform destroy` everything and `terraform apply` to rebuild it identically."

### Why Terraform over CloudFormation

**The simple answer:** "CloudFormation only works with AWS. Terraform works with AWS, Azure, GCP, and 3,000+ other providers. If a portfolio company is on Azure, the same Terraform skills and patterns apply. CloudFormation would lock me into AWS-only."

### Why a reusable module

**The simple answer:** "I have 10 S3 buckets that all need the same security baseline — encryption, versioning, public access blocked, SSL-only policy, lifecycle rules. Instead of writing that configuration 10 times, I wrote it once as a module and call it 10 times with different names. If I need to change the encryption standard, I change it in one place and all 10 buckets inherit it."

### How onboarding works

**The simple answer:** "Adding a new portfolio company to the platform takes about 15 lines of Terraform. Copy the module call, change the company name, run `terraform apply`. The reusable module handles all the security configuration automatically."

### Why remote state

**The simple answer:** "Terraform keeps track of what it has built in a state file. If that file is on my laptop and someone else also runs Terraform, we'd overwrite each other. Remote state stores it in S3, and DynamoDB locking prevents two people from running Terraform at the same time. It costs about 25 cents a month."

---

## GitHub Actions — Why CI/CD

### Why automated deployment

**The simple answer:** "I never run `terraform apply` from my laptop. Every change goes through a pull request, gets a security scan and cost estimate, and deploys automatically when merged. This means every infrastructure change is reviewed, documented, and auditable."

### Why OIDC over stored credentials

**The simple answer:** "GitHub authenticates to AWS using a temporary token that expires immediately. There are no AWS access keys stored in GitHub Secrets, my laptop, or anywhere else. If my GitHub account were compromised, the attacker still couldn't access AWS — the OIDC federation validates that the request is coming from a specific repository in a specific GitHub organization."

### How the PR pipeline works

**The simple answer:** "When I open a pull request that changes infrastructure code, three things run automatically:
1. `terraform plan` — shows exactly what will be created, modified, or destroyed
2. `tfsec` — scans for security misconfigurations (unencrypted buckets, overly permissive IAM)
3. `Infracost` — calculates the monthly cost impact of the change

All three results are posted as PR comments. The reviewer sees the infrastructure diff, security results, and cost impact before approving."

### Why Infracost

**The simple answer:** "Every pull request shows the estimated monthly cost change. If someone adds a NAT Gateway ($32/month) or a large RDS instance, the team sees the dollar impact before it merges. No surprise bills."

---

## The Platform — Big Picture

### What Apex Vault does (simple)

"Apex Vault is a data platform that takes financial data from multiple companies, validates it, encrypts it, catalogs it, and makes it queryable with SQL — all automatically. Each company gets its own isolated environment. The entire platform runs on AWS, is defined in Terraform, and deploys via GitHub Actions."

### Why it matters

"When a PE firm acquires a company, the first thing they need is visibility into the financials. Usually that means weeks of consultants building spreadsheets. Apex Vault automates that — upload the data, and it's queryable in seconds. As the firm acquires more companies, each one gets onboarded with 15 lines of Terraform."

### What makes it production-grade

"This isn't a demo. Every bucket is encrypted. Every role follows least privilege. Every change goes through CI/CD with security scanning. The monitoring dashboard catches failures automatically. The cost is under $5/month. That's what 'production-grade' means — it's not just functional, it's secure, observable, and cost-efficient."

---

## Quick Reference — Numbers to Know

| Metric | Value |
|---|---|
| Portfolio companies onboarded | 4 |
| AWS services used | 9 (S3, Lambda, DynamoDB, Athena, Glue, VPC, IAM, CloudWatch, SNS) |
| Terraform resources managed | ~40+ |
| S3 buckets | 10 (reusable module) |
| Lambda processing time | ~206ms average |
| Monthly infrastructure cost | ~$4.75 |
| Lines to onboard a new company | ~15 (Terraform) |
| Static AWS credentials stored | 0 (OIDC) |
| Architecture Decision Records | 6 |
| CI/CD pipelines | 2 (plan + deploy) |
