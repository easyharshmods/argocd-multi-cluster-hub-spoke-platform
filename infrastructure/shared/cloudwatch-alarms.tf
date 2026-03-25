// CloudWatch Logs metric + alarm for Dagster run failures.
// Triggered by log lines containing the marker string from the Dagster failure sensor.

resource "aws_cloudwatch_log_metric_filter" "dagster_run_failures" {
  name           = "${var.project_name}-dagster-run-failures"
  log_group_name = aws_cloudwatch_log_group.eks_containers.name
  pattern        = "ALERT_DAGSTER_RUN_FAILURE"

  metric_transformation {
    name      = "DagsterRunFailures"
    namespace = "Dagster/Monitoring"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "dagster_run_failure_alarm" {
  alarm_name          = "${var.project_name}-dagster-run-failure"
  alarm_description   = "Alerts when a Dagster job run fails (see /aws/eks/${var.project_name}-cluster/containers logs for details)."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "DagsterRunFailures"
  namespace           = "Dagster/Monitoring"
  period              = 60
  statistic           = "Sum"
  threshold           = 1

  treat_missing_data = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# Pre-create main log group so retention can be set
resource "aws_cloudwatch_log_group" "eks_containers" {
  name              = "/aws/eks/${var.project_name}-cluster/containers"
  retention_in_days = 30
  tags              = local.common_tags
}
