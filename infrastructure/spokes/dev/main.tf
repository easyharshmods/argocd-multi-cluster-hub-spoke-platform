# Dev spoke cluster infrastructure

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
      Environment = "dev"
      ManagedBy   = "Terraform"
      Project     = "dagster-platform"
      Role        = "spoke-cluster"
    }
  }
}

locals {
  cluster_name = "dagster-dev"
  vpc_cidr     = "10.10.0.0/16"
}
