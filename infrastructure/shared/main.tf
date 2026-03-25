# Shared infrastructure — cross-cluster resources
# Route53, ACM, Cognito, ECR, Secrets Manager, SNS, CloudWatch

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Configured via backend-config during init
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "shared"
      ManagedBy   = "Terraform"
      Project     = var.project_name
    }
  }
}

# us-east-1 provider for Route53 Domains API
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Route53: when route53_zone_id is empty we create the zone (see route53.tf); otherwise use the given ID.
locals {
  route53_zone_id   = var.route53_zone_id != "" ? trimspace(var.route53_zone_id) : aws_route53_zone.main[0].zone_id
  route53_zone_name = "${var.domain_name}."

  # For Route53 Domains nameserver sync: use created zone's name_servers or var.route53_name_servers
  route53_name_servers = var.domain_registered_in_route53_domains ? (var.route53_zone_id != "" ? var.route53_name_servers : aws_route53_zone.main[0].name_servers) : []

  common_tags = merge(
    var.common_tags,
    {
      Terraform = "true"
      Region    = var.aws_region
      AccountId = data.aws_caller_identity.current.account_id
    }
  )
}
