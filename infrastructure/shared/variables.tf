# From bootstrap/terraform-backend (auto-generated in 00-bootstrap.auto.tfvars)
variable "tfstate_bucket_name" {
  description = "S3 bucket name for Terraform state"
  type        = string
}

variable "tfstate_kms_key_id" {
  description = "KMS key ID for state encryption"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

# Configuration variables
variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the platform (e.g. platform.example.com)"
  type        = string
}

variable "route53_zone_id" {
  description = "Optional: Route53 hosted zone ID for your domain. Leave empty to have Terraform create a new public hosted zone for domain_name. If set, use the ID from Route53 → Hosted zones → your domain → 'Hosted zone ID'."
  type        = string
  default     = ""

  validation {
    condition     = var.route53_zone_id == "" || (can(regex("^Z[A-Z0-9]+$", trimspace(var.route53_zone_id))) && length(trimspace(var.route53_zone_id)) >= 12)
    error_message = "route53_zone_id must be empty or a valid Route53 hosted zone ID (e.g. Z1234567890ABC, 12+ chars, starts with Z)."
  }
}

variable "domain_registered_in_route53_domains" {
  description = "Set to true if the domain is registered with Route53 Domains (same account) and you want Terraform to set the domain's nameservers to the hosted zone's NS (for ACM validation and DNS)."
  type        = bool
  default     = false
}

variable "route53_name_servers" {
  description = "List of nameservers from the hosted zone (e.g. [\"ns-123.awsdns-45.com\", ...]). Required when domain_registered_in_route53_domains=true; copy from Route53 → Hosted zones → your zone → NS record."
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}
