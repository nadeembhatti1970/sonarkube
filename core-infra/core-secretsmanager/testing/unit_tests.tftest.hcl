# ---------------------------------------------------------------------------
# Unit tests: secret inventory, encryption and write-only versioning.
#
# The generated credentials are ephemeral; tests assert the *contract* (names,
# KMS binding, version counters) without ever reading a secret value.
# ---------------------------------------------------------------------------
mock_provider "aws" {}

# Pin the KMS key ARN so plan-time assertions can verify the binding.
override_resource {
  target          = aws_kms_key.secrets
  override_during = plan
  values = {
    arn = "arn:aws:kms:eu-west-1:123456789012:key/11111111-2222-3333-4444-555555555555"
  }
}

variables {
  project     = "sonarkube"
  environment = "dev"
  aws_region  = "eu-west-1"

  state_bucket_name = "sonarkube-dev-eu-west-1-tfstate"
}

run "secrets_are_encrypted_with_cmk" {
  command = plan

  assert {
    condition     = aws_secretsmanager_secret.rds_master.kms_key_id == aws_kms_key.secrets.arn
    error_message = "RDS credentials must be encrypted with the environment secrets key."
  }

  assert {
    condition     = aws_secretsmanager_secret.sonarqube_admin_password.kms_key_id == aws_kms_key.secrets.arn
    error_message = "SonarQube credentials must be encrypted with the environment secrets key."
  }

  assert {
    condition     = aws_kms_key.secrets.enable_key_rotation
    error_message = "The secrets key must rotate annually."
  }
}

run "secret_names_are_predictable" {
  command = plan

  assert {
    condition     = aws_secretsmanager_secret.rds_master.name == "sonarkube-dev/rds/master"
    error_message = "The RDS master secret must follow the sonarkube-dev/rds/master convention."
  }

  assert {
    condition     = aws_secretsmanager_secret.sonarqube_admin_current_password.name == "sonarkube-dev/sonarqube/admin-current-password"
    error_message = "The current admin password secret must be discoverable by name for the chart hook."
  }

  assert {
    condition     = aws_secretsmanager_secret.sonarqube_admin_password.name == "sonarkube-dev/sonarqube/admin-password"
    error_message = "The admin password secret must be discoverable by name."
  }

  assert {
    condition     = aws_secretsmanager_secret.kubernetes_kubeconfig.name == "sonarkube-dev/kubernetes/kubeconfig"
    error_message = "The kubeconfig secret must be discoverable by name."
  }
}

run "versions_are_write_only_and_versioned" {
  command = plan

  assert {
    condition     = aws_secretsmanager_secret_version.sonarqube_admin_password.secret_string_wo_version == 1
    error_message = "The admin password version must be tracked by a revision counter, not a stored value."
  }

  assert {
    condition     = aws_secretsmanager_secret_version.sonarqube_monitoring_passcode.secret_string_wo_version == 1
    error_message = "The monitoring passcode version must be tracked by a revision counter."
  }

  assert {
    condition     = aws_secretsmanager_secret_version.sonarqube_server_secret_key.secret_string_wo_version == 1
    error_message = "The server encryption key version must be tracked by a revision counter."
  }

  assert {
    condition     = aws_secretsmanager_secret_version.sonarqube_admin_current_password.secret_string_wo_version == 1
    error_message = "The current admin password version must be tracked by a revision counter."
  }
}

run "rotation_is_off_by_default" {
  command = plan

  assert {
    condition     = length(aws_secretsmanager_secret_rotation.rds_master) == 0
    error_message = "Automatic rotation must stay disabled unless a rotation Lambda is supplied."
  }
}

run "rotation_can_be_enabled" {
  command = plan

  variables {
    enable_rds_master_rotation     = true
    rds_master_rotation_lambda_arn = "arn:aws:lambda:eu-west-1:123456789012:function:rotate-rds"
    rds_master_rotation_days       = 30
  }

  assert {
    condition     = length(aws_secretsmanager_secret_rotation.rds_master) == 1
    error_message = "Rotation must be configured when a rotation Lambda ARN is supplied."
  }
}

run "rejects_invalid_credentials_version" {
  command = plan

  variables {
    sonarqube_credentials_version = 0
  }

  expect_failures = [var.sonarqube_credentials_version]
}

run "rejects_short_recovery_window" {
  command = plan

  variables {
    secret_recovery_window_in_days = 3
  }

  expect_failures = [var.secret_recovery_window_in_days]
}
