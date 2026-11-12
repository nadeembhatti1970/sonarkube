# ---------------------------------------------------------------------------
# IAM role that lets the RDS service publish Enhanced Monitoring metrics to
# CloudWatch on behalf of the instance. Scoped to the AWS managed policy that
# ships with RDS; no inline wildcard permissions.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "rds_enhanced_monitoring_assume_role" {
  statement {
    sid     = "AllowRdsToAssumeMonitoringRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:rds:${var.aws_region}:${data.aws_caller_identity.current.account_id}:db:${local.db_identifier}"]
    }
  }
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name                 = "${local.name_prefix}-rds-enhanced-monitoring"
  description          = "Allows RDS to publish Enhanced Monitoring metrics for ${local.db_identifier}"
  assume_role_policy   = data.aws_iam_policy_document.rds_enhanced_monitoring_assume_role.json
  max_session_duration = 3600

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-rds-enhanced-monitoring" })
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
