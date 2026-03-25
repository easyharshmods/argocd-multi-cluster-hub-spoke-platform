# Production spoke cluster infrastructure

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
      Environment = "production"
      ManagedBy   = "Terraform"
      Project     = "dagster-platform"
      Role        = "spoke-cluster"
    }
  }
}

locals {
  cluster_name = "dagster-prod"
  vpc_cidr     = "10.30.0.0/16"
}
