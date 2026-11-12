# ---------------------------------------------------------------------------
# SonarQube credentials.
#
# All three values are generated as Terraform *ephemeral* resources: they only
# exist in memory during apply and are handed to the provider through
# write-only arguments. They are never written to state, plan files, console
# output or Helm values.
#
#   * admin-password   -> local SonarQube administrator password
#   * passcode         -> monitoring passcode used by the health endpoints
#   * server-secret-key -> sonar-secret.txt, protects stored settings
#                          (SCM/webhook credentials) and must stay stable
#
# Bump `sonarqube_credentials_version` to rotate all three deliberately.
# ---------------------------------------------------------------------------
ephemeral "random_password" "sonarqube_admin" {
  length           = var.sonarqube_admin_password_length
  special          = true
  override_special = local.password_special_characters
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
}

ephemeral "random_password" "sonarqube_monitoring_passcode" {
  length  = 32
  special = false
  upper   = true
  lower   = true
  numeric = true
}

ephemeral "random_password" "sonarqube_server_secret_key" {
  length  = 64
  special = false
  upper   = true
  lower   = true
  numeric = true
}

# ---------------------------------------------------------------------------
# Secret containers.
# ---------------------------------------------------------------------------
#checkov:skip=CKV2_AWS_57:Secret versions are written write-only by the owning module; rotation is a deliberate version bump.
resource "aws_secretsmanager_secret" "sonarqube_database" {
  name                    = local.secret_names.sonarqube_database
  description             = "JDBC connection details for SonarQube (version written by core-rds)"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = var.secret_recovery_window_in_days

  tags = merge(local.common_tags, { Name = local.secret_names.sonarqube_database })
}

#checkov:skip=CKV2_AWS_57:Rotation is a deliberate `sonarqube_credentials_version` bump coordinated with setAdminPassword.
resource "aws_secretsmanager_secret" "sonarqube_admin_password" {
  name                    = local.secret_names.sonarqube_admin_password
  description             = "SonarQube local administrator password"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = var.secret_recovery_window_in_days

  tags = merge(local.common_tags, { Name = local.secret_names.sonarqube_admin_password })
}

#checkov:skip=CKV2_AWS_57:Rotation is a deliberate `sonarqube_credentials_version` bump.
resource "aws_secretsmanager_secret" "sonarqube_monitoring_passcode" {
  name                    = local.secret_names.sonarqube_monitoring_passcode
  description             = "SonarQube monitoring passcode for health endpoints"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = var.secret_recovery_window_in_days

  tags = merge(local.common_tags, { Name = local.secret_names.sonarqube_monitoring_passcode })
}

#checkov:skip=CKV2_AWS_57:Rotating the server encryption key requires re-encrypting stored settings; this is a manual runbook, not a Lambda.
resource "aws_secretsmanager_secret" "sonarqube_server_secret_key" {
  name                    = local.secret_names.sonarqube_server_secret_key
  description             = "SonarQube sonar-secret.txt server-side encryption key"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = var.secret_recovery_window_in_days

  tags = merge(local.common_tags, { Name = local.secret_names.sonarqube_server_secret_key })
}

# The previous administrator password, consumed by the chart's
# setAdminPassword hook as `currentPassword`. It is "admin" on first boot and
# must be supplied through TF_VAR_sonarqube_current_admin_password on rotation.
#
#checkov:skip=CKV2_AWS_57:Coordinated with the chart hook and the SonarQube restart runbook.
resource "aws_secretsmanager_secret" "sonarqube_admin_current_password" {
  name                    = local.secret_names.sonarqube_admin_current_password
  description             = "SonarQube administrator password currently in use (bootstrap: admin)"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = var.secret_recovery_window_in_days

  tags = merge(local.common_tags, { Name = local.secret_names.sonarqube_admin_current_password })
}

# ---------------------------------------------------------------------------
# Secret versions, written with write-only arguments.
# ---------------------------------------------------------------------------
resource "aws_secretsmanager_secret_version" "sonarqube_admin_password" {
  secret_id                = aws_secretsmanager_secret.sonarqube_admin_password.id
  secret_string_wo         = ephemeral.random_password.sonarqube_admin.result
  secret_string_wo_version = var.sonarqube_credentials_version
}

resource "aws_secretsmanager_secret_version" "sonarqube_monitoring_passcode" {
  secret_id                = aws_secretsmanager_secret.sonarqube_monitoring_passcode.id
  secret_string_wo         = ephemeral.random_password.sonarqube_monitoring_passcode.result
  secret_string_wo_version = var.sonarqube_credentials_version
}

resource "aws_secretsmanager_secret_version" "sonarqube_server_secret_key" {
  secret_id                = aws_secretsmanager_secret.sonarqube_server_secret_key.id
  secret_string_wo         = ephemeral.random_password.sonarqube_server_secret_key.result
  secret_string_wo_version = var.sonarqube_credentials_version
}

resource "aws_secretsmanager_secret_version" "sonarqube_admin_current_password" {
  secret_id                = aws_secretsmanager_secret.sonarqube_admin_current_password.id
  secret_string_wo         = var.sonarqube_current_admin_password
  secret_string_wo_version = var.sonarqube_credentials_version
}
