# ---------------------------------------------------------------------------
# Customer managed KMS key for VPC flow logs.
#
# Flow logs contain source/destination addresses and ports for every ENI in
# the VPC, so they are treated as confidential telemetry and encrypted at rest
# with a key the platform team owns and rotates.
# ---------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

resource "aws_kms_key" "flow_logs" {
  description             = "Encrypts VPC flow logs for ${local.name_prefix}"
  deletion_window_in_days = var.flow_log_kms_deletion_window_in_days
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
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-flow-logs-kms" })
}

resource "aws_kms_alias" "flow_logs" {
  name          = "alias/${local.name_prefix}-vpc-flow-logs"
  target_key_id = aws_kms_key.flow_logs.key_id
}
