# ---------------------------------------------------------------------------
# PostgreSQL parameter group tuned for SonarQube.
#
# SonarQube opens a bounded pool of connections and performs heavy analytical
# queries during report generation; the settings below raise the connection
# ceiling, keep slow queries visible in the logs and force TLS for every
# session.
# ---------------------------------------------------------------------------
resource "aws_db_parameter_group" "sonarqube" {
  name        = "${local.name_prefix}-sonarqube-pg17"
  family      = "postgres${split(".", var.engine_version)[0]}"
  description = "SonarQube tuned PostgreSQL parameters for ${local.name_prefix}"

  # Encryption in transit is enforced explicitly (not via the dynamic map) so
  # that policy scanners and reviewers can see it directly.
  parameter {
    name         = "rds.force_ssl"
    value        = var.force_ssl ? "1" : "0"
    apply_method = "pending-reboot"
  }

  dynamic "parameter" {
    for_each = local.postgres_parameters

    content {
      name         = parameter.key
      value        = parameter.value
      apply_method = "pending-reboot"
    }
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-sonarqube-pg17" })

  lifecycle {
    create_before_destroy = true
  }
}
