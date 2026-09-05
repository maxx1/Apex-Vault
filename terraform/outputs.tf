# =============================================================================
# Outputs
# =============================================================================
# Key values displayed after terraform apply.
# Useful for testing, debugging, and integrating with other tools.
# =============================================================================

output "raw_data_bucket_name" {
  description = "Name of the raw data S3 bucket — upload files here"
  value       = module.raw_data_bucket.bucket_id
}

output "processed_data_bucket_name" {
  description = "Name of the processed data S3 bucket — clean data lands here"
  value       = module.processed_data_bucket.bucket_id
}

output "lambda_function_name" {
  description = "Name of the data processor Lambda function"
  value       = aws_lambda_function.data_processor.function_name
}

output "lambda_function_arn" {
  description = "ARN of the data processor Lambda function"
  value       = aws_lambda_function.data_processor.arn
}

output "cloudwatch_dashboard_url" {
  description = "URL to the CloudWatch monitoring dashboard"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${var.project_name}-${var.environment}-pipeline"
}

output "sns_topic_arn" {
  description = "ARN of the SNS alert topic"
  value       = aws_sns_topic.alerts.arn
}

output "client_analyst_role_arn" {
  description = "IAM role ARN for client data analysts (read-only processed data)"
  value       = aws_iam_role.client_analyst.arn
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC — use this in your repo secrets"
  value       = aws_iam_role.github_actions.arn
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}
