# Shared infrastructure outputs — consumed by hub and spoke terraform via remote state

# Route53
output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = local.route53_zone_id
}

output "route53_zone_name" {
  description = "Route53 hosted zone name"
  value       = var.domain_name
}

output "route53_name_servers" {
  description = "Nameservers for the hosted zone (when zone is created by Terraform). Add these at your domain registrar so DNS and ACM validation work."
  value       = length(aws_route53_zone.main) > 0 ? aws_route53_zone.main[0].name_servers : []
}

# ACM
output "acm_certificate_arn" {
  description = "ACM wildcard certificate ARN"
  value       = aws_acm_certificate.wildcard.arn
}

# Cognito
output "cognito_user_pool_id" {
  description = "Cognito user pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_arn" {
  description = "Cognito user pool ARN"
  value       = aws_cognito_user_pool.main.arn
}

output "cognito_domain" {
  description = "Cognito domain"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "cognito_client_id_dagster" {
  description = "Cognito app client ID for Dagster"
  value       = aws_cognito_user_pool_client.dagster.id
  sensitive   = true
}

output "cognito_client_id_grafana" {
  description = "Cognito app client ID for Grafana"
  value       = aws_cognito_user_pool_client.grafana.id
  sensitive   = true
}

# ECR
output "ecr_repository_url" {
  description = "ECR repository URL for Dagster user code"
  value       = aws_ecr_repository.dagster_user_code.repository_url
}

output "external_dns_ecr_repository_url" {
  description = "ECR repository URL for External DNS image (mirror Bitnami image here to avoid pull issues)"
  value       = aws_ecr_repository.external_dns.repository_url
}

output "ecr_kms_key_arn" {
  description = "KMS key ARN for ECR encryption"
  value       = aws_kms_key.ecr.arn
}

# SNS
output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = aws_sns_topic.alerts.arn
}

# Secrets Manager
output "rds_secret_arn" {
  description = "RDS credentials secret ARN"
  value       = aws_secretsmanager_secret.rds_credentials.arn
}

output "rds_secret_name" {
  description = "RDS credentials secret name"
  value       = aws_secretsmanager_secret.rds_credentials.name
}

output "secrets_kms_key_arn" {
  description = "KMS key ARN for Secrets Manager encryption"
  value       = aws_kms_key.secrets.arn
}

# IAM policies (shared, cluster-specific IRSA roles reference these)
output "fluent_bit_cloudwatch_policy_arn" {
  description = "IAM policy ARN for Fluent Bit CloudWatch Logs access"
  value       = aws_iam_policy.fluent_bit_cloudwatch.arn
}

# Domain
output "domain_name" {
  description = "Domain name for the platform"
  value       = var.domain_name
}

output "dagster_fqdn" {
  description = "Dagster FQDN"
  value       = "dagster.${var.domain_name}"
}

output "grafana_fqdn" {
  description = "Grafana FQDN"
  value       = "grafana.${var.domain_name}"
}
