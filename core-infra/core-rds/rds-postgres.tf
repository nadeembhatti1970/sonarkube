# ---------------------------------------------------------------------------
# RDS PostgreSQL instance for SonarQube.
#
# Production guard rails:
#   * Multi-AZ with automated backups and a final snapshot on destroy
#   * deletion_protection on, no public endpoint, isolated subnet group
#   * gp3 storage encrypted with a customer managed key
#   * Enhanced Monitoring + Performance Insights + PostgreSQL log exports
#   * IAM database authentication enabled for short-lived operator access
# ---------------------------------------------------------------------------
resource "aws_db_instance" "sonarqube" {
  identifier = local.db_identifier

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.db_username
  port     = var.db_port

  # Write-only: the ephemeral password is never persisted in state or plan.
  password_wo         = ephemeral.random_password.master.result
  password_wo_version = var.db_password_revision

  db_subnet_group_name   = data.terraform_remote_state.vpc.outputs.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  network_type           = "IPV4"

  multi_az                 = var.multi_az
  storage_type             = "gp3"
  allocated_storage        = var.allocated_storage
  max_allocated_storage    = var.max_allocated_storage
  iops                     = var.storage_iops
  storage_throughput       = var.storage_throughput
  storage_encrypted        = true
  kms_key_id               = aws_kms_key.rds.arn
  copy_tags_to_snapshot    = true
  delete_automated_backups = false

  backup_retention_period     = var.backup_retention_days
  backup_window               = var.backup_window
  maintenance_window          = var.maintenance_window
  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false
  apply_immediately           = false

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.db_identifier}-final"

  parameter_group_name = aws_db_parameter_group.sonarqube.name
  ca_cert_identifier   = var.ca_cert_identifier

  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn

  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.rds.arn
  performance_insights_retention_period = var.performance_insights_retention_days

  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade"]
  iam_database_authentication_enabled = true

  timeouts {
    create = "90m"
    update = "120m"
    delete = "90m"
  }

  tags = merge(local.common_tags, { Name = local.db_identifier })
}
