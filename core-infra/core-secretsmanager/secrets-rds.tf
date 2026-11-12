# ---------------------------------------------------------------------------
# RDS PostgreSQL master credentials.
#
# The secret *container* is owned here; the secret *version* is written by
# core-rds with a write-only argument, using an ephemeral password. Terraform
# therefore never persists the password in state or in a plan file.
# ---------------------------------------------------------------------------
#checkov:skip=CKV2_AWS_57:Automatic rotation needs a VPC-attached rotation Lambda; rotation is optional and wired below.
resource "aws_secretsmanager_secret" "rds_master" {
  name                    = local.secret_names.rds_master
  description             = "Master credentials for the ${local.name_prefix} RDS PostgreSQL instance"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = var.secret_recovery_window_in_days

  tags = merge(local.common_tags, { Name = local.secret_names.rds_master })
}

resource "aws_secretsmanager_secret_rotation" "rds_master" {
  count = var.enable_rds_master_rotation ? 1 : 0

  secret_id           = aws_secretsmanager_secret.rds_master.id
  rotation_lambda_arn = var.rds_master_rotation_lambda_arn

  rotation_rules {
    automatically_after_days = var.rds_master_rotation_days
  }
}
