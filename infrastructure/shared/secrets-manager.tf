resource "aws_kms_key" "secrets" {
  description             = "KMS key for Secrets Manager"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    local.common_tags,
    { Name = "${var.project_name}-secrets-encryption" }
  )
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project_name}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "aws_secretsmanager_secret" "rds_credentials" {
  name                    = "${var.project_name}-rds-credentials"
  description             = "RDS PostgreSQL database credentials for Dagster"
  kms_key_id              = aws_kms_key.secrets.id
  recovery_window_in_days = 7

  tags = local.common_tags
}

# Note: The secret version (with actual credentials) is managed by the cluster
# terraform that creates the RDS instance, since it needs the RDS endpoint.
