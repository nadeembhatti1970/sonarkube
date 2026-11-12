# ---------------------------------------------------------------------------
# Alerting.
#
# RDS metrics and events are routed to an encrypted SNS topic. The topic and
# its key only accept publishers from this account, and the key only allows
# CloudWatch and SNS to use it for this account's resources.
# ---------------------------------------------------------------------------
resource "aws_kms_key" "alarms" {
  description             = "Encrypts the ${local.name_prefix} database alarm topic"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableAccountAdministration"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchAndSnsUse"
        Effect = "Allow"
        Principal = {
          Service = ["cloudwatch.amazonaws.com", "sns.amazonaws.com"]
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-rds-alarms-kms" })
}

resource "aws_kms_alias" "alarms" {
  name          = "alias/${local.name_prefix}-rds-alarms"
  target_key_id = aws_kms_key.alarms.key_id
}

resource "aws_sns_topic" "database_alarms" {
  name              = "${local.name_prefix}-rds-alarms"
  kms_master_key_id = aws_kms_key.alarms.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-rds-alarms" })
}

resource "aws_sns_topic_policy" "database_alarms" {
  arn = aws_sns_topic.database_alarms.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAccountAdministration"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "sns:*"
        Resource = aws_sns_topic.database_alarms.arn
      },
      {
        Sid    = "AllowCloudWatchAlarmsPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.database_alarms.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AllowRdsEventsPublish"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.database_alarms.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:rds:${var.aws_region}:${data.aws_caller_identity.current.account_id}:db:*"
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "database_alarms_email" {
  count = var.alarm_email == null ? 0 : 1

  topic_arn = aws_sns_topic.database_alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${local.db_identifier}-cpu-high"
  alarm_description   = "CPU utilisation on ${local.db_identifier} stayed above ${var.cpu_alarm_threshold_percent}% for 10 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold_percent
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.database_alarms.arn]
  ok_actions          = [aws_sns_topic.database_alarms.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.sonarqube.identifier
  }

  tags = merge(local.common_tags, { Name = "${local.db_identifier}-cpu-high" })
}

resource "aws_cloudwatch_metric_alarm" "freeable_memory_low" {
  alarm_name          = "${local.db_identifier}-freeable-memory-low"
  alarm_description   = "Freeable memory on ${local.db_identifier} dropped below ${var.freeable_memory_alarm_threshold_bytes} bytes"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.freeable_memory_alarm_threshold_bytes
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.database_alarms.arn]
  ok_actions          = [aws_sns_topic.database_alarms.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.sonarqube.identifier
  }

  tags = merge(local.common_tags, { Name = "${local.db_identifier}-freeable-memory-low" })
}

resource "aws_cloudwatch_metric_alarm" "free_storage_low" {
  alarm_name          = "${local.db_identifier}-free-storage-low"
  alarm_description   = "Free storage on ${local.db_identifier} dropped below ${var.free_storage_alarm_threshold_bytes} bytes"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.free_storage_alarm_threshold_bytes
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.database_alarms.arn]
  ok_actions          = [aws_sns_topic.database_alarms.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.sonarqube.identifier
  }

  tags = merge(local.common_tags, { Name = "${local.db_identifier}-free-storage-low" })
}

resource "aws_cloudwatch_metric_alarm" "connections_high" {
  alarm_name          = "${local.db_identifier}-connections-high"
  alarm_description   = "Database connections on ${local.db_identifier} exceeded ${var.max_connections_alarm_threshold}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Maximum"
  threshold           = var.max_connections_alarm_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.database_alarms.arn]
  ok_actions          = [aws_sns_topic.database_alarms.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.sonarqube.identifier
  }

  tags = merge(local.common_tags, { Name = "${local.db_identifier}-connections-high" })
}

resource "aws_db_event_subscription" "sonarqube" {
  name             = "${local.db_identifier}-events"
  sns_topic        = aws_sns_topic.database_alarms.arn
  source_type      = "db-instance"
  source_ids       = [aws_db_instance.sonarqube.identifier]
  event_categories = ["availability", "failure", "maintenance", "configuration change"]
  enabled          = true

  tags = merge(local.common_tags, { Name = "${local.db_identifier}-events" })
}
