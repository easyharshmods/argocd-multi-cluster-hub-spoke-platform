# Staging RDS PostgreSQL — isolated metadata store for staging Dagster

module "rds" {
  source = "../../../terraform/modules/rds"

  cluster_name       = local.cluster_name
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [aws_security_group.rds.id]
  engine_version     = "17.2"
  instance_class     = "db.t3.micro"
  multi_az           = false

  db_name     = "dagster"
  db_username = "dagster"
  db_password = var.db_password

  tags = {
    Environment = "staging"
    Component   = "dagster-metadata"
  }
}
