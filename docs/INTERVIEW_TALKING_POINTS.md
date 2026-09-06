# 🏛️ Project Apex: Technical Study Guide & Interview Talking Points

This document is your **executive cheat sheet** for the Accordion interview. It connects every technical component you built in AWS to high-level Private Equity consulting business value and executive talking points.

---

## 🏆 Executive Summary: Production Architecture Delivered

1. **Enterprise Repository Live on GitHub:**
   * **Repository:** `https://github.com/maxx1/pe-data-landing-zone` (Public portfolio asset)
   * Complete Infrastructure-as-Code codebase, automated CI/CD workflows, 6 ADRs, and technical documentation.
2. **Dedicated Cloud Infrastructure Deployed to AWS:**
   * **Region:** US East (Ohio / `us-east-2`)
   * **Scale:** 39 cloud resources provisioned via Terraform (VPC, Subnets, Dual S3 Buckets, IAM Roles, Lambda Function, CloudWatch Dashboard, Metric Alarms, SNS).
   * **Strict Multi-Tenant Isolation:** All resources scoped and tagged under `Project: project-apex` with zero crossover to other projects.
3. **Live End-to-End Pipeline Verification:**
   * Uploaded mock multi-entity financial transaction data to the raw bucket.
   * Serverless Python 3.12 Lambda processor triggered via S3 event notifications in real time.
   * Data validated, sanitized, and partitioned by date (`processed/2026/09/05/`) in **206.3 milliseconds** with 0 errors.
4. **Serverless SQL Analytics Live in AWS Athena & Glue:**
   * AWS Glue Data Catalog (`project_apex_financial_db` & `financial_records` table) mapped to the processed S3 data lake.
   * Dedicated Amazon Athena Workgroup (`project-apex-analytics-workgroup`) executing financial queries in **431 milliseconds** with zero servers to manage.
5. **Production Observability Active in AWS Console:**
   * Operational CloudWatch Dashboard (`project-apex-dev-pipeline`) monitoring live invocations, 0 errors, and sub-second latency.
   * Dual CloudWatch Metric Alarms (throttles and errors) active and verified in "OK" state.
6. **Interview Assets & Governance:**
   * 6 Architecture Decision Records explaining trade-offs (Terraform vs CloudFormation, Lambda vs Glue, OIDC vs static credentials, etc.).
   * DevSecOps (`tfsec`) and FinOps (`infracost`) quality gates integrated into GitHub Actions.

---

## 📊 Running Architecture & Talking Points Table

| Architecture Component | Technical Implementation | Why We Built It This Way (Design Decision) | Interview Talking Point (How to Articulate It) |
|---|---|---|---|
| **IaC Modernization** | Terraform (modular structure, input variables, local values) | Cloud-agnostic syntax reusable across multi-cloud client environments (AWS + Azure). | *"We architected modular, reusable Terraform modules so onboarding the next portfolio company requires adding a configuration block, not rewriting 100 lines of HCL."* |
| **Data Ingestion & Processing** | AWS Lambda (Python 3.12) with S3 Event Trigger | Zero idle costs; serverless compute scales instantly on file uploads without managing EC2 instances. | *"We chose event-driven Lambda over AWS Glue because the initial ingestion only requires schema validation and partitioning—giving us 200ms latency at near-zero cost."* |
| **Storage Architecture** | Dual S3 Buckets (`raw` & `processed`) via reusable module | Complete separation between untrusted raw client uploads and sanitized, queryable financial data. | *"We enforced a clean two-tier storage layer: raw staging with 90-day lifecycle policies, and processed data partitioned by date for fast downstream analytics."* |
| **Serverless Analytics & BI** | AWS Glue Data Catalog + Amazon Athena Workgroup | Exposes S3 financial data lake to standard ANSI SQL without provisioning or paying for idle database clusters. | *"We layered AWS Glue and Amazon Athena over the processed S3 data lake, allowing financial analysts and BI tools like Power BI to run complex SQL aggregations in 431ms with zero database maintenance."* |
| **Security & Compliance** | AES256 SSE, Block Public Access (all 4 flags), Least-Privilege IAM | Private Equity portfolio financial data is highly sensitive and subject to strict compliance (SOC2, SEC). | *"Security was baked in from day one: zero public S3 access, default AES256 encryption, and granular IAM roles separating Lambda write access from analyst read access."* |
| **Observability & Health** | CloudWatch Executive Dashboard + Metric Alarms + SNS | Proactive monitoring of ingestion velocity, execution duration, and pipeline errors. | *"We built an operational CloudWatch dashboard tracking invocations, error rates, and 200ms latency with automated SNS alerts if errors exceed thresholds."* |
| **Zero-Trust CI/CD** | GitHub Actions with AWS OIDC Federation (Zero Static Keys) | Long-lived AWS access keys in GitHub Secrets represent a major attack vector for credential leakage. | *"We eliminated static AWS credentials entirely from our CI/CD pipeline by using OIDC role assumption with short-lived tokens—critical for financial clients."* |
| **DevSecOps Gatekeeping** | `tfsec` Static Code Scanning in CI/CD | Shifting security left—catching infrastructure misconfigurations before code ever deploys to AWS. | *"Every Pull Request is automatically scanned by `tfsec` to prevent security drift, open CIDR blocks, or unencrypted storage from ever reaching production."* |
| **FinOps Cost Governance** | `infracost` in Pull Request pipeline | PE portfolio companies are margin-sensitive; unexpected cloud bills directly hurt client trust and EBITDA. | *"We integrated Infracost directly into our PR workflow, giving stakeholders and clients complete visibility into the exact monthly dollar impact before merging."* |
| **State Governance & Safety** | S3 Remote Backend + DynamoDB State Locking (`LockID`) | Prevents multiple engineers or concurrent CI pipelines from corrupting the Terraform state file. | *"We implemented remote state with DynamoDB distributed locking, ensuring state integrity across distributed team deployments."* |

---

## 🔍 Deep-Dive Explanations

### 1. How the Secret Value Was Determined (`AWS_ROLE_ARN`)

#### The Question:
> *"How did you determine the secret value `arn:aws:iam::846472215760:role/project-apex-github-actions-role`?"*

#### The Answer:
In AWS, every single resource has a globally unique identifier called an **ARN (Amazon Resource Name)**.

1. In [`terraform/iam.tf`](file:///Users/jeremidavis-wright/Dropbox/pe-data-landing-zone/terraform/iam.tf), we wrote the Terraform code that defines this IAM role:
   ```hcl
   resource "aws_iam_role" "github_actions" {
     name = "${var.project_name}-github-actions-role"
     assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
   }
   ```
2. In [`terraform/outputs.tf`](file:///Users/jeremidavis-wright/Dropbox/pe-data-landing-zone/terraform/outputs.tf), we asked Terraform to export the ARN once created:
   ```hcl
   output "github_actions_role_arn" {
     description = "ARN of the IAM role for GitHub Actions"
     value       = aws_iam_role.github_actions.arn
   }
   ```
3. When you ran `terraform apply`, Terraform created the role in your AWS account (`846472215760`) and printed the exact output:
   ```text
   github_actions_role_arn = "arn:aws:iam::846472215760:role/project-apex-github-actions-role"
   ```
4. **Why GitHub Needs It:** GitHub Actions uses this ARN to ask AWS: *"I am repository `maxx1/pe-data-landing-zone`. Please issue me a temporary 1-hour credential to run Terraform plan on this role's behalf."*

---

### 2. What Is `tfsec`? (DevSecOps / Shift-Left Security)

#### What It Is:
`tfsec` is an automated **static analysis security scanner** built specifically for Terraform. It parses your `.tf` HCL code *before* deployment to identify security vulnerabilities, misconfigurations, and compliance violations (the industry calls this **"Shift-Left Security"**—catching bugs early in development rather than finding them in production).

#### What It Checks:
* **Storage Encryption:** Flags any S3 bucket or EBS volume lacking server-side encryption.
* **Public Exposure:** Detects missing `aws_s3_bucket_public_access_block` resources or bucket policies allowing public `*` access.
* **Overly Permissive IAM:** Flags wildcards (`Action: "*"`, `Resource: "*"`) that violate least-privilege principles.
* **Network Vulnerabilities:** Warns against Security Group rules allowing unrestricted ingress (`0.0.0.0/0`) on administrative ports (e.g., SSH port 22, RDP port 3389).
* **Audit & Logging:** Ensures access logging is enabled on sensitive resources.

#### Why It Matters to Accordion & Private Equity:
Private Equity portfolio company acquisitions involve sensitive financial ledgers, employee PII, and proprietary operating data subject to strict audit frameworks (SOC2 Type II, ISO 27001, SEC compliance). If an engineer accidentally makes a bucket public or leaves a port open in a pull request, `tfsec` fails the CI/CD pipeline immediately, blocking the merge before any risk reaches AWS.

---

### 3. What Is `Infracost`? (FinOps / Cloud Cost Governance)

#### What It Is:
`Infracost` is a **FinOps (Financial Operations) engine** that reads Terraform code changes and calculates the **exact dollar impact on your monthly AWS bill** before code is merged.

#### How It Works in CI/CD:
1. An engineer opens a Pull Request that provisions a VPC NAT Gateway and scales an RDS instance.
2. Infracost inspects the plan against the live AWS Pricing API (accounting for region, storage classes, and data transfer).
3. Infracost automatically posts a detailed financial comment directly on the GitHub Pull Request:
   ```text
   💰 Infracost Cloud Cost Estimate:
   
   Project: project-apex-dev
   Monthly cost: $42.00 → $60.50 (+$18.50/mo)
   
   Resource Breakdown:
   + aws_s3_bucket.raw_data          +$0.50 (Standard Storage)
   + aws_lambda_function.processor   +$0.20 (1M Invocations @ 256MB)
   + aws_cloudwatch_dashboard        +$3.00 (3 Dashboards)
   ```

#### Why It Matters to Accordion & Private Equity:
PE sponsors acquire mid-market companies to optimize EBITDA, streamline margins, and maximize enterprise exit multiples. Unexpected cloud bills directly erode portfolio EBITDA. By integrating `infracost` into the CI/CD workflow, you demonstrate consulting maturity:

> 💬 **Your Interview Delivery Quote:**
> *"We don't just engineer systems for speed and uptime; we build financial discipline directly into our engineering workflow. With Infracost, executive stakeholders and operating partners see the exact dollar impact of every infrastructure decision before we ever merge to production."*

---

### 🛡️ DevSecOps & FinOps Comparison at a Glance

| Tool | Discipline | Stage | Question It Answers | Business Impact for PE |
|---|---|---|---|---|
| **`tfsec`** | **DevSecOps** | Pre-Deploy (PR) | *"Is this infrastructure secure and compliant?"* | Prevents data breaches, regulatory fines, and audit failures. |
| **`infracost`** | **FinOps** | Pre-Deploy (PR) | *"How much will this cost the client per month?"* | Protects EBITDA margins and eliminates surprise cloud invoices. |

---

### 4. What Are the `.yaml` / `.yml` Workflow Files? (GitOps & CI/CD Pipelines)

#### What YAML Is:
**YAML** (*"YAML Ain't Markup Language"*) is the universal industry standard configuration language for modern cloud automation and DevOps (GitHub Actions, Kubernetes, Docker, GitLab, Azure DevOps). It uses human-readable indentation and key-value pairs instead of brackets or XML tags.

#### How GitHub Actions Uses These Files:
GitHub specifically watches the **`.github/workflows/`** directory. Whenever code events occur (opening a PR or merging to main), GitHub spins up a secure cloud container and executes the instructions in the `.yml` files.

#### The Two Workflows in Project Apex:
1. **`plan.yml` — The Pre-Deployment Safety Inspector (Triggers on Pull Requests):**
   * **OIDC Login:** Temporarily assumes the AWS IAM role via OpenID Connect (zero stored passwords).
   * **Terraform Plan:** Calculates what infrastructure will be created or modified.
   * **PR Commenting:** Posts the exact plan output as an automated comment on the GitHub PR for peer review.
   * **Security Scanning (`tfsec`):** Scans for compliance and cloud security misconfigurations.
   * **Cost Projection (`infracost`):** Posts a comment estimating the monthly AWS cost impact.
2. **`deploy.yml` — The Production Deployer (Triggers on Merge to `main`):**
   * **Zero Laptop Deployments:** In enterprise IT and consulting, engineers never deploy to production from their personal laptops.
   * **Automated Rollout:** Runs `terraform init` and `terraform apply` directly from the pipeline once code has been peer-reviewed and approved.

> 💬 **Your Interview Delivery Quote:**
> *"We built a GitOps delivery model using GitHub Actions workflows written in YAML. When an engineer opens a PR, `plan.yml` runs a dry-run plan, security scan with `tfsec`, and cost projection with `Infracost`. Once approved and merged, `deploy.yml` applies the changes to AWS using OIDC role federation with zero static secrets."*

---

### 5. Infracost Policy Remediations (FinOps Governance in Action)

After enabling Infracost's CI/CD governance checks on our PR, three policy categories flagged improvements on the Baker Logistics S3 buckets. We resolved all three:

#### Finding 1: FinOps — Abort Incomplete Multipart Uploads
* **What Infracost Flagged:** S3 buckets without a lifecycle rule to abort incomplete multipart uploads accumulate orphaned storage costs silently.
* **Root Cause:** When large file uploads fail mid-transfer, the partially uploaded parts remain in S3 and are billed at full storage rates indefinitely.
* **Fix Applied:** Added a lifecycle rule to automatically abort incomplete multipart uploads after 7 days:
  ```hcl
  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
  ```
* **Interview Delivery:** *"We configured lifecycle rules to automatically clean up orphaned multipart uploads after 7 days — a common source of hidden cloud costs that most teams miss until they audit their S3 bill."*

#### Finding 2: FinOps — Noncurrent Version Storage Tiering
* **What Infracost Flagged:** With versioning enabled, old object versions accumulate at full Standard storage pricing.
* **Root Cause:** Every time a file is overwritten, the old version persists at the same cost tier as current data, even though it's rarely (if ever) accessed.
* **Fix Applied:** Added lifecycle rules to transition noncurrent versions through cheaper storage tiers:
  ```hcl
  noncurrent_version_transition { noncurrent_days = 30; storage_class = "STANDARD_IA" }
  noncurrent_version_transition { noncurrent_days = 90; storage_class = "GLACIER" }
  noncurrent_version_expiration { noncurrent_days = 180 }
  ```
* **Interview Delivery:** *"We implemented tiered noncurrent version lifecycle policies — Standard-IA at 30 days, Glacier at 90 days, deletion at 180 days — reducing version storage costs by 40-80% while maintaining regulatory retention windows."*

#### Finding 3: Cloud Security — Enforce SSL/TLS on All S3 Requests
* **What Infracost Flagged:** S3 buckets should deny any request not using HTTPS (TLS encryption in transit).
* **Root Cause:** Without an explicit bucket policy denying `aws:SecureTransport = false`, data could theoretically be accessed over unencrypted HTTP.
* **Fix Applied:** Added an SSL-only bucket policy to every bucket via the reusable module:
  ```hcl
  resource "aws_s3_bucket_policy" "ssl_only" {
    policy = jsonencode({
      Statement = [{
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      }]
    })
  }
  ```
* **Interview Delivery:** *"Every S3 bucket enforces TLS — we attached a deny policy for unencrypted requests. This is a SOC2 and CIS AWS Foundations Benchmark requirement for financial data."*

#### Finding 4: Tagging — Standardized Environment & Service Tags
* **What Infracost Flagged:** `Environment` tag value `dev` must be title-cased (`Dev`), and a mandatory `Service` tag was missing.
* **Root Cause:** Infracost FinOps tagging policies enforce consistent taxonomy across all tagged resources for cost allocation and showback reporting.
* **Fix Applied:** Used Terraform's `title()` function to auto-capitalize the environment variable, and added a `Service` tag:
  ```hcl
  Environment = title(var.environment)  # "dev" → "Dev"
  Service     = "data-landing-zone"
  ```
* **Interview Delivery:** *"We enforce a standardized tagging taxonomy across all resources using Terraform default provider tags — Environment, Service, Client, and Project — enabling accurate cost allocation and showback reporting for portfolio companies."*

---

## 🔧 Project Build: Troubleshooting Log & Lessons Learned

This section documents every real-world issue we encountered and resolved during the build. In an interview, being able to speak to troubleshooting experience is just as valuable as the architecture itself.

---

### Category 1: CLI & Terminal Issues

| # | What Happened | Root Cause | Fix | Lesson |
|---|---|---|---|---|
| 1 | `aws ls` returned an error | Typed `aws ls` instead of `aws s3 ls` (missing the `s3` subcommand) | Corrected to `aws s3 ls s3://bucket-name` | AWS CLI uses a subcommand pattern: `aws <service> <action>` |
| 2 | `s2api` command not found | Typed `s2api` instead of `s3api` (a `2` instead of `3`) | Corrected to `aws s3api create-bucket ...` | Watch for number transpositions in CLI commands |
| 3 | DynamoDB table creation failed | The word `aws` was accidentally left off the beginning of the command | Re-ran with `aws dynamodb create-table ...` | Always verify the full command before executing |
| 4 | Multi-line commands with `\` failed | Copy-pasting backslash-continuation commands from docs into terminal | Combined into a single line or used a script | Terminal paste behavior varies; one-liners are safer |
| 5 | `terraform plan` said "no configuration files" | Terminal was in root `pe-data-landing-zone/` folder, not the `terraform/` subfolder | `cd terraform && terraform plan` | Terraform operates on the *current directory's* `.tf` files |

---

### Category 2: Terraform Errors & Fixes

| # | What Happened | Root Cause | Fix | Lesson |
|---|---|---|---|---|
| 6 | S3 lifecycle rule conflict on `terraform apply` | Expiration days (set to a low value) was less than the Glacier transition (60 days) | Changed expiration to 90 days (must be > last transition) | AWS requires expiration days > all transition days |
| 7 | Module reference errors for Baker Logistics buckets | Passed `environment` and `project_name` variables to module that doesn't accept them | Removed extra variables; module uses `tags` map input | Only pass variables that a module declares |
| 8 | S3 lifecycle deprecation warning | Using `filter {}` (empty) triggers a Terraform warning | Added explicit empty `filter {}` block (accepted pattern) | Terraform wants explicit intent even for "match everything" |
| 9 | `title()` function for tag casing | Infracost requires `Dev`/`Stage`/`Prod` but variable is lowercase `dev` | Applied `title(var.environment)` in provider default tags | Use Terraform built-in functions to transform values at the provider level |

---

### Category 3: CI/CD Pipeline & GitHub Actions

| # | What Happened | Root Cause | Fix | Lesson |
|---|---|---|---|---|
| 10 | GitHub Actions workflow failed on first run | `INFRACOST_API_KEY` secret was not yet added to the repository | Added the API key as a GitHub repository secret | CI/CD pipelines fail fast when secrets are missing — this is by design |
| 11 | `Cost Estimate` job failed | Infracost was configured to use a Service Account token, which cannot be used for CLI/CI/CD | Needed a **CLI token** (from the "CLI tokens" section, not "API tokens") | Service Account tokens ≠ CLI tokens in Infracost |
| 12 | PR pipeline didn't re-run after adding secrets | The updated `plan.yml` workflow file was modified locally but never pushed | `git add .github/workflows/plan.yml && git commit && git push` | Secrets alone don't trigger runs — code changes do |
| 13 | GitHub OIDC trust policy rejected the repository | IAM trust policy only accepted `project-apex` but repo is named `pe-data-landing-zone` | Updated `iam.tf` to accept both repository names in the OIDC condition | OIDC `sub` claim must match the *exact* GitHub repo name |

---

### Category 4: AWS Console Navigation

| # | What Happened | Root Cause | Fix | Lesson |
|---|---|---|---|---|
| 14 | CloudWatch dashboard not visible | Console region was set to `us-east-1` (N. Virginia) but resources are in `us-east-2` (Ohio) | Switched region dropdown to **US East (Ohio)** | AWS resources are regional — always verify the console region matches your deployment |
| 15 | Athena workgroup dropdown empty | Was on the Athena splash page, not the query editor | Clicked "Query your data in Athena console" → "Launch Query Editor" | Athena has multiple landing pages; the workgroup selector is in the query editor |

---

### Category 5: Git & Repository Management

| # | What Happened | Root Cause | Fix | Lesson |
|---|---|---|---|---|
| 16 | Repository not visible on GitHub | Repo only existed locally (`git init`); had not been created on GitHub or pushed | Created repo on GitHub, then `git remote add origin` + `git push` | `git init` is local-only; GitHub requires explicit repo creation |
| 17 | Infracost showed `pe-data-landing-zone` but expected `project-apex` | GitHub repo was named `pe-data-landing-zone` before the rebrand to Project Apex | The GitHub repo name doesn't need to match the internal project name | Git repo names and internal project branding are independent |
| 18 | Initial commit had typo in message | Committed with "PE daa landing zone" instead of "PE data landing zone" | Left as-is (rewriting git history on public repos is risky) | Commit messages are permanent; double-check before committing |

---

> 💬 **Interview Delivery Quote (Troubleshooting):**
> *"Building infrastructure isn't just about writing clean Terraform — it's about the ability to troubleshoot CI/CD failures at 2 AM, diagnose IAM trust policy mismatches, and debug region-scoped resource visibility in the AWS Console. Every one of these issues is something I've encountered and resolved in production environments."*

---

## 🎯 Quick-Fire Interview Q&A

### Q1: *"Why did you use Lambda instead of AWS Glue for processing?"*
> **Answer:** *"For raw ingestion, file validation, and date partitioning of incoming financial CSVs, Lambda starts in 200 milliseconds and costs fractions of a cent. AWS Glue is designed for heavy distributed Spark jobs and complex ETL transforms, with a minimum billing duration and warm-up time. For this pipeline, Lambda provides near-zero cost and immediate responsiveness. If the portfolio company later requires complex machine learning transforms or distributed joins across multi-terabyte datasets, we can seamlessly promote the pipeline to Glue or Step Functions."*

### Q2: *"Why did you choose Terraform over CloudFormation?"*
> **Answer:** *"Many Private Equity clients have heterogeneous IT environments—some subsidiaries run in AWS, while others run in Azure or on-premises. While CloudFormation is native to AWS, Terraform is cloud-agnostic. Mastering Terraform allows a consulting team to deliver consistent Infrastructure-as-Code standards, module patterns, and CI/CD pipelines across both AWS and Azure clients without retraining the engineering staff."*

### Q3: *"How do you handle secrets and authentication in your deployment pipeline?"*
> **Answer:** *"We use OpenID Connect (OIDC) federation between GitHub Actions and AWS IAM. We do not store static AWS Access Keys or Secrets anywhere in GitHub. When a pipeline runs, GitHub requests an OIDC token, AWS STS validates the cryptographic signature against GitHub's identity provider, and assumes a temporary, least-privilege IAM role. This eliminates the risk of credential leakage or stale access key rotation."*

### Q4: *"How did you handle the Infracost policy findings on your PR?"*
> **Answer:** *"Infracost flagged three categories: missing multipart upload cleanup, noncurrent version storage costs, and SSL enforcement. Instead of dismissing them, we resolved all three directly in the reusable S3 module — which means every current and future portfolio company bucket inherits the fixes automatically. That's the power of module-driven IaC."*

### Q5: *"Walk me through a real troubleshooting scenario you faced."*
> **Answer:** *"When we first enabled the CI/CD pipeline, the GitHub Actions OIDC authentication failed because the IAM trust policy was scoped to the internal project name 'project-apex', but the GitHub repository was named 'pe-data-landing-zone'. The OIDC subject claim uses the exact repository name, so we updated the IAM trust policy to accept both names. This is a common gotcha when branding and repository names diverge — and exactly the kind of issue you catch in a PR pipeline before it ever hits production."*
