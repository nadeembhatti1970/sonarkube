# ---------------------------------------------------------------------------
# Credential publication.
#
# Every version is written with a write-only argument (secret_string_wo) and a
# version counter, so Terraform never persists the password. Two projections
# are maintained:
#
#   rds/master            JSON with username/password/dbname/port
#                         (humans, DB tooling, rotation Lambda)
#   sonarqube/database    JSON with the full JDBC connection details, read at
#                         runtime by External Secrets Operator
#
# Bump `db_password_revision` to rotate the password; the ephemeral password is
# regenerated and all three versions are rewritten in the same apply, while RDS
# receives the new password through password_wo.
# ---------------------------------------------------------------------------
resource "aws_secretsmanager_secret_version" "rds_master" {
  secret_id = data.terraform_remote_state.secretsmanager.outputs.rds_master_secret_arn

  secret_string_wo = jsonencode({
    engine   = "postgres"
    username = var.db_username
    password = ephemeral.random_password.master.result
    dbname   = var.db_name
    port     = var.db_port
  })

  secret_string_wo_version = var.db_password_revision
}

resource "aws_secretsmanager_secret_version" "sonarqube_database" {
  secret_id = data.terraform_remote_state.secretsmanager.outputs.sonarqube_database_secret_arn

  secret_string_wo = jsonencode({
    engine   = "postgres"
    host     = aws_db_instance.sonarqube.address
    port     = var.db_port
    database = var.db_name
    username = var.db_username
    password = ephemeral.random_password.master.result
    sslmode  = local.jdbc_sslmode
    jdbc_url = local.jdbc_url
  })

  secret_string_wo_version = var.db_password_revision

  depends_on = [aws_db_instance.sonarqube]
}
