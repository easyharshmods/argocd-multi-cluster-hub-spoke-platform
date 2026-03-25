variable "aws_region" {
  description = "AWS region for dev spoke cluster"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "dagster-platform"
}

variable "tfstate_bucket_name" {
  description = "S3 bucket for Terraform state (for remote state lookups)"
  type        = string
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}
