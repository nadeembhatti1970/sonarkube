# ---------------------------------------------------------------------------
# Unit tests: database isolation, resilience and audit defaults.
#
# Cross-stack state and the Secrets Manager payload are pinned with
# override_data so the suite runs offline and deterministically.
# ---------------------------------------------------------------------------
mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"monitoring.rds.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    }
  }
}

override_data {
  target = data.aws_partition.current
  values = { partition = "aws" }
}

override_data {
  target = data.terraform_remote_state.vpc
  values = {
    outputs = {
      vpc_id                            = "vpc-0123456789abcdef0"
      database_subnet_group_name        = "sonarkube-dev-db"
      database_client_security_group_id = "sg-0123456789abcdef0"
      database_subnet_ids               = ["subnet-0aaa", "subnet-0bbb", "subnet-0ccc"]
    }
  }
}

override_data {
  target = data.terraform_remote_state.secretsmanager
  values = {
    outputs = {
      rds_master_secret_arn         = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:sonarkube-dev/rds/master-AbCdEf"
      sonarqube_database_secret_arn = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:sonarkube-dev/sonarqube/database-AbCdEf"
    }
  }
}

variables {
  project     = "sonarkube"
  environment = "dev"
  aws_region  = "eu-west-1"

  state_bucket_name = "sonarkube-dev-eu-west-1-tfstate"

  engine_version = "17.6"
  instance_class = "db.m6g.large"
}

run "database_is_private_and_resilient" {
  command = plan

  assert {
    condition     = aws_db_instance.sonarqube.publicly_accessible == false
    error_message = "The database must never be publicly accessible."
  }

  assert {
    condition     = aws_db_instance.sonarqube.multi_az
    error_message = "Multi-AZ must be enabled for production resilience."
  }

  assert {
    condition     = aws_db_instance.sonarqube.deletion_protection
    error_message = "Deletion protection must be enabled."
  }

  assert {
    condition     = aws_db_instance.sonarqube.skip_final_snapshot == false
    error_message = "A final snapshot must be taken on destroy."
  }

  assert {
    condition     = aws_db_instance.sonarqube.backup_retention_period == 14
    error_message = "Automated backups must be retained for 14 days."
  }

  assert {
    condition     = aws_db_instance.sonarqube.storage_encrypted
    error_message = "Storage encryption must be enabled."
  }

  assert {
    condition     = aws_db_instance.sonarqube.performance_insights_enabled
    error_message = "Performance Insights must be enabled for query-level triage."
  }

  assert {
    condition     = aws_db_instance.sonarqube.monitoring_interval == 60
    error_message = "Enhanced Monitoring must publish at 60 second granularity."
  }

  assert {
    condition     = contains(aws_db_instance.sonarqube.enabled_cloudwatch_logs_exports, "postgresql")
    error_message = "PostgreSQL logs must be exported to CloudWatch Logs."
  }

  assert {
    condition     = aws_db_instance.sonarqube.db_subnet_group_name == "sonarkube-dev-db"
    error_message = "The instance must use the isolated database subnet group."
  }
}

run "database_accepts_only_database_clients" {
  command = plan

  assert {
    condition     = aws_vpc_security_group_ingress_rule.postgres_from_clients.referenced_security_group_id == "sg-0123456789abcdef0"
    error_message = "PostgreSQL ingress must reference the shared database-clients security group."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.postgres_from_clients.from_port == 5432
    error_message = "Ingress must be limited to the PostgreSQL port."
  }
}

run "parameter_group_is_hardened" {
  command = plan

  assert {
    condition     = aws_db_parameter_group.sonarqube.family == "postgres17"
    error_message = "The parameter group family must follow the engine major version."
  }

  assert {
    condition = length([
      for parameter in aws_db_parameter_group.sonarqube.parameter : parameter
      if parameter.name == "rds.force_ssl" && parameter.value == "1"
    ]) == 1
    error_message = "rds.force_ssl must be enabled by default."
  }
}

run "jdbc_secret_targets_the_managed_secret" {
  command = plan

  assert {
    condition     = aws_secretsmanager_secret_version.sonarqube_database.secret_id == "arn:aws:secretsmanager:eu-west-1:123456789012:secret:sonarkube-dev/sonarqube/database-AbCdEf"
    error_message = "The JDBC connection details must be written to the secret created by core-secretsmanager."
  }

  assert {
    condition     = aws_db_instance.sonarqube.parameter_group_name == aws_db_parameter_group.sonarqube.name
    error_message = "The instance must use the SonarQube tuned parameter group."
  }
}

run "alarms_cover_cpu_memory_storage_and_connections" {
  command = plan

  assert {
    condition     = aws_cloudwatch_metric_alarm.cpu_high.namespace == "AWS/RDS" && aws_cloudwatch_metric_alarm.cpu_high.metric_name == "CPUUtilization"
    error_message = "A sustained CPU alarm must exist."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.freeable_memory_low.comparison_operator == "LessThanThreshold"
    error_message = "The memory alarm must fire when freeable memory drops."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.connections_high.threshold == 180
    error_message = "The connection alarm must use the configured threshold."
  }

  assert {
    condition     = aws_db_event_subscription.sonarqube.enabled
    error_message = "RDS availability and failure events must be forwarded to SNS."
  }
}

run "rejects_excessive_backup_retention" {
  command = plan

  variables {
    backup_retention_days = 40
  }

  expect_failures = [var.backup_retention_days]
}

run "rejects_overlapping_invalid_windows" {
  command = plan

  variables {
    maintenance_window = "sunday:04:00-05:00"
  }

  expect_failures = [var.maintenance_window]
}
