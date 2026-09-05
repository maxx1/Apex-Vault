# =============================================================================
# Monitoring, Alerting & Dashboard
# =============================================================================
# CloudWatch monitoring stack:
# - Log Group for Lambda execution logs (7-day retention)
# - Alarms for errors and throttling
# - SNS topic for alert notifications
# - Dashboard for real-time pipeline visibility
#
# In a consulting context, this monitoring gives the PE client visibility
# into their data pipeline health without needing to understand AWS internals.
# =============================================================================

# --- CloudWatch Log Group ---
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-processor"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-logs"
  }
}

# --- SNS Topic for Alerts ---
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# --- CloudWatch Alarm: Lambda Errors ---
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-lambda-errors"
  alarm_description   = "Triggers when Lambda data processor has errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.data_processor.function_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

# --- CloudWatch Alarm: Lambda Throttling ---
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.project_name}-${var.environment}-lambda-throttles"
  alarm_description   = "Triggers when Lambda is being throttled — may indicate scaling issues"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.data_processor.function_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# --- CloudWatch Dashboard ---
# Real-time visibility into the data pipeline health
resource "aws_cloudwatch_dashboard" "pipeline" {
  dashboard_name = "${var.project_name}-${var.environment}-pipeline"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Lambda Invocations (Files Processed)"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.data_processor.function_name]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Lambda Errors"
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.data_processor.function_name]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Processing Duration (ms)"
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.data_processor.function_name]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Lambda Throttles"
          metrics = [
            ["AWS/Lambda", "Throttles", "FunctionName", aws_lambda_function.data_processor.function_name]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          view   = "timeSeries"
        }
      }
    ]
  })
}
