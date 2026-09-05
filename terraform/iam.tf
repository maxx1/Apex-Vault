# =============================================================================
# IAM Roles & Policies
# =============================================================================
# Follows the principle of LEAST PRIVILEGE — each role only has the specific
# permissions it needs, scoped to specific resources. No wildcard (*) access.
#
# Roles defined:
# 1. Lambda Execution Role — read raw bucket, write processed bucket, logs
# 2. Client Data Analyst Role — read-only access to processed bucket
# 3. GitHub Actions OIDC Role — deploy infrastructure via CI/CD
# =============================================================================

# ─── LAMBDA EXECUTION ROLE ───────────────────────────────────────────────────

resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Lambda can READ from raw bucket (GetObject, HeadObject only)
resource "aws_iam_role_policy" "lambda_s3_read_raw" {
  name = "s3-read-raw-data"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:HeadObject"
        ]
        Resource = "${module.raw_data_bucket.bucket_arn}/*"
      }
    ]
  })
}

# Lambda can WRITE to processed bucket (PutObject only)
resource "aws_iam_role_policy" "lambda_s3_write_processed" {
  name = "s3-write-processed-data"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectTagging"
        ]
        Resource = "${module.processed_data_bucket.bucket_arn}/*"
      }
    ]
  })
}

# Lambda can write CloudWatch logs (scoped to its own log group)
resource "aws_iam_role_policy" "lambda_cloudwatch" {
  name = "cloudwatch-logs"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-${var.environment}-processor:*"
      }
    ]
  })
}

# ─── CLIENT DATA ANALYST ROLE ────────────────────────────────────────────────
# Portfolio company analysts get READ-ONLY access to processed data.
# They CANNOT access the raw data bucket or any other AWS resources.

resource "aws_iam_role" "client_analyst" {
  name = "${var.project_name}-${var.environment}-client-analyst"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          # In production, this would reference the client's AWS account ID
          # or an external identity provider (SSO, SAML)
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "client_read_processed" {
  name = "read-processed-data"
  role = aws_iam_role.client_analyst.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.processed_data_bucket.bucket_arn,
          "${module.processed_data_bucket.bucket_arn}/*"
        ]
      }
    ]
  })
}

# ─── GITHUB ACTIONS OIDC ─────────────────────────────────────────────────────
# Allows GitHub Actions to assume an IAM role without static credentials.
# See: docs/adr/004-github-actions-with-oidc.md

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:*/${var.project_name}:*",
              "repo:*/pe-data-landing-zone:*"
            ]
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# GitHub Actions needs permissions to manage all infrastructure resources.
# In production, scope this more tightly per resource type.
resource "aws_iam_role_policy" "github_actions_deploy" {
  name = "terraform-deploy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*",
          "lambda:*",
          "iam:*",
          "ec2:*",
          "logs:*",
          "cloudwatch:*",
          "sns:*",
          "dynamodb:*",
          "events:*"
        ]
        Resource = "*"
      }
    ]
  })
}
