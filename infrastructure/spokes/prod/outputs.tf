output "cluster_name" {
  description = "Production spoke EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Production spoke EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Production spoke EKS cluster CA data"
  value       = module.eks.cluster_certificate_authority_data
}

output "vpc_id" {
  description = "Production spoke VPC ID"
  value       = module.vpc.vpc_id
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.endpoint
}

output "rds_address" {
  description = "RDS hostname"
  value       = module.rds.address
}

output "rds_port" {
  description = "RDS port"
  value       = module.rds.port
}

output "aws_lb_controller_role_arn" {
  description = "ALB controller IAM role ARN"
  value       = module.aws_lb_controller_irsa_role.iam_role_arn
}

output "external_secrets_role_arn" {
  description = "External Secrets IAM role ARN"
  value       = module.external_secrets_irsa_role.iam_role_arn
}

output "external_dns_role_arn" {
  description = "External DNS IAM role ARN"
  value       = module.external_dns_irsa_role.iam_role_arn
}

output "fluent_bit_role_arn" {
  description = "Fluent Bit IAM role ARN"
  value       = module.fluent_bit_irsa_role.iam_role_arn
}
