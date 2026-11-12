# ---------------------------------------------------------------------------
# CloudWatch log groups for the PostgreSQL and upgrade logs exported by RDS.
#
# RDS creates these groups implicitly when log export is enabled, but without
# a retention policy. Declaring them here gives us encryption with the database
# log key and a bounded retention period.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "postgresql" {
  name              = "/aws/rds/instance/${local.db_identifier}/postgresql"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = aws_kms_key.logs.arn

  tags = merge(local.common_tags, { Name = "${local.db_identifier}-postgresql-logs" })
}

resource "aws_cloudwatch_log_group" "upgrade" {
  name              = "/aws/rds/instance/${local.db_identifier}/upgrade"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = aws_kms_key.logs.arn

  tags = merge(local.common_tags, { Name = "${local.db_identifier}-upgrade-logs" })
}
