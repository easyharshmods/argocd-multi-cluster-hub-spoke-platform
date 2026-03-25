# Hub cluster outputs — consumed by ArgoCD and platform components

# VPC
output "vpc_id" {
  description = "Hub VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Hub private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Hub public subnet IDs"
  value       = module.vpc.public_subnets
}

# EKS
output "cluster_name" {
  description = "Hub EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Hub EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Hub EKS cluster CA data"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Hub EKS cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Hub EKS node security group ID"
  value       = module.eks.node_security_group_id
}

output "oidc_provider_arn" {
  description = "Hub OIDC provider ARN"
  value       = module.eks.oidc_provider_arn
}

# IAM roles for platform components
output "aws_lb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = module.aws_lb_controller_irsa_role.iam_role_arn
}

output "external_secrets_role_arn" {
  description = "IAM role ARN for External Secrets Operator"
  value       = module.external_secrets_irsa_role.iam_role_arn
}

output "external_dns_role_arn" {
  description = "IAM role ARN for External DNS"
  value       = module.external_dns_irsa_role.iam_role_arn
}

output "adot_collector_role_arn" {
  description = "IAM role ARN for ADOT OpenTelemetry Collector"
  value       = module.adot_collector_irsa_role.iam_role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler"
  value       = module.cluster_autoscaler_irsa_role.iam_role_arn
}

output "fluent_bit_role_arn" {
  description = "IAM role ARN for Fluent Bit (CloudWatch Logs)"
  value       = module.fluent_bit_irsa_role.iam_role_arn
}

# Security Groups
output "rds_security_group_id" {
  description = "Security group ID for RDS access from this cluster"
  value       = module.rds_security_group.security_group_id
}

# Shared infrastructure references (passed through for convenience)
output "route53_zone_id" {
  description = "Route53 hosted zone ID (from shared infrastructure)"
  value       = local.shared.route53_zone_id
}

output "acm_certificate_arn" {
  description = "ACM wildcard certificate ARN (from shared infrastructure)"
  value       = local.shared.acm_certificate_arn
}

output "ecr_repository_url" {
  description = "ECR repository URL (from shared infrastructure)"
  value       = local.shared.ecr_repository_url
}

output "cognito_user_pool_id" {
  description = "Cognito user pool ID (from shared infrastructure)"
  value       = local.shared.cognito_user_pool_id
}

output "cognito_user_pool_arn" {
  description = "Cognito user pool ARN (from shared infrastructure)"
  value       = local.shared.cognito_user_pool_arn
}

output "cognito_domain" {
  description = "Cognito domain (from shared infrastructure)"
  value       = local.shared.cognito_domain
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts (from shared infrastructure)"
  value       = local.shared.sns_topic_arn
}

output "domain_name" {
  description = "Domain name (from shared infrastructure)"
  value       = local.shared.domain_name
}

output "dagster_fqdn" {
  description = "Dagster FQDN (from shared infrastructure)"
  value       = local.shared.dagster_fqdn
}

output "grafana_fqdn" {
  description = "Grafana FQDN (from shared infrastructure)"
  value       = local.shared.grafana_fqdn
}
