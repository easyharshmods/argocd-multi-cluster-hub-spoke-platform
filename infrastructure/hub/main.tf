# Hub cluster infrastructure — central control plane for multi-cluster management

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
      Environment = "hub"
      ManagedBy   = "Terraform"
      Project     = "dagster-platform"
      Role        = "hub-cluster"
    }
  }
}

locals {
  cluster_name = "dagster-hub"
  vpc_cidr     = "10.0.0.0/16"
  common_tags = {
    Environment = "hub"
    ManagedBy   = "Terraform"
    Project     = var.project_name
    Role        = "hub-cluster"
  }
}
