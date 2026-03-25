# Reusable RDS PostgreSQL module for Dagster metadata storage
# Used by each spoke cluster for isolated metadata per environment

resource "aws_db_subnet_group" "this" {
  name       = "${var.cluster_name}-db-subnet"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.cluster_name}-db-subnet"
  }
}

resource "aws_db_instance" "this" {
  identifier = "${var.cluster_name}-rds"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.security_group_ids

  backup_retention_period = var.backup_retention_period
  multi_az                = var.multi_az
  skip_final_snapshot     = var.skip_final_snapshot

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  monitoring_interval                   = 60

  tags = var.tags
}
