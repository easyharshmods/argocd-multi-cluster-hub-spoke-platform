# bootstrap/terraform-backend configuration

aws_region   = "eu-central-1"
project_name = "dagster-platform"

common_tags = {
  Project     = "dagster-platform"
  Environment = "production"
  ManagedBy   = "terraform"
  Component   = "bootstrap"
  CostCenter  = "data-engineering"
}
