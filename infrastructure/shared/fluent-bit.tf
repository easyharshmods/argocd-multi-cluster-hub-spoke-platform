# ──────────────────────────────────────────────────────────────────────────────
# Fluent Bit: IAM policy for CloudWatch Logs access
# Note: The IRSA role itself is created per-cluster (in hub/spoke terraform)
# since it needs the cluster's OIDC provider. This file defines the shared
# CloudWatch Logs policy that cluster-specific roles can reference.
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_iam_policy" "fluent_bit_cloudwatch" {
  name        = "${var.project_name}-fluent-bit-cloudwatch"
  description = "Allow Fluent Bit to write EKS container logs to CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.project_name}*:*",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.project_name}*/*:*"
        ]
      }
    ]
  })

  tags = local.common_tags
}
