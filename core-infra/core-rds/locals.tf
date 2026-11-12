# ---------------------------------------------------------------------------
# Shared locals, parameter tuning and the ephemeral database password.
#
# The master password is generated as an ephemeral resource: it exists in
# memory during apply only. It is passed to RDS and Secrets Manager through
# write-only arguments, so it never appears in state, plan files or logs.
# ---------------------------------------------------------------------------
ephemeral "random_password" "master" {
  length           = var.db_password_length
  special          = true
  override_special = "!#%*-_=+"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

locals {
  # Non-secret connection metadata. The password is intentionally absent.
  jdbc_sslmode = var.force_ssl ? "require" : "disable"

  jdbc_url = format(
    "jdbc:postgresql://%s:%d/%s%s",
    aws_db_instance.sonarqube.address,
    var.db_port,
    var.db_name,
    var.force_ssl ? "?sslmode=require" : "",
  )

  postgres_parameters = {
    max_connections                     = "200"
    shared_buffers                      = "{DBInstanceClassMemory/32768}"
    work_mem                            = "16384"
    maintenance_work_mem                = "{DBInstanceClassMemory/16384}"
    effective_cache_size                = "{DBInstanceClassMemory/16384}"
    log_min_duration_statement          = "1000"
    log_connections                     = "1"
    log_disconnections                  = "1"
    log_lock_waits                      = "1"
    log_temp_files                      = "0"
    idle_in_transaction_session_timeout = "900000"
    statement_timeout                   = "0"
  }
}
