# Production RDS PostgreSQL — HA metadata store for production Dagster

module "rds" {
  source = "../../../terraform/modules/rds"

  cluster_name       = local.cluster_name
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [aws_security_group.rds.id]
  engine_version     = "17.2"
  instance_class     = "db.t3.small"
  multi_az           = true

  allocated_storage     = 50
  max_allocated_storage = 200

  backup_retention_period = 14
  skip_final_snapshot     = false

  db_name     = "dagster"
  db_username = "dagster"
  db_password = var.db_password

  tags = {
    Environment = "production"
    Component   = "dagster-metadata"
  }
}
