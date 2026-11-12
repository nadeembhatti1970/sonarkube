# ---------------------------------------------------------------------------
# Integration test: plans the database stack with TLS disabled, proving the
# parameter group and JDBC secret stay consistent for environments that
# terminate TLS elsewhere.
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
  force_ssl         = false
}

run "tls_can_be_terminated_by_the_caller" {
  command = plan

  assert {
    condition = length([
      for parameter in aws_db_parameter_group.sonarqube.parameter : parameter
      if parameter.name == "rds.force_ssl" && parameter.value == "0"
    ]) == 1
    error_message = "rds.force_ssl must be explicitly disabled when force_ssl is false."
  }

  assert {
    condition     = aws_sns_topic.database_alarms.name == "sonarkube-dev-rds-alarms"
    error_message = "The alarm topic must always be created with the environment naming convention."
  }
}
