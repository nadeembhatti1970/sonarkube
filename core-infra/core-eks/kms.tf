# ---------------------------------------------------------------------------
# CloudWatch Logs key for the EKS control plane log group.
#
# Cluster audit logs contain API request bodies, including the names of
# Secrets and ConfigMaps, so they are encrypted with a key the platform team
# controls and retained for a bounded period.
# ---------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

resource "aws_kms_key" "logs" {
  description             = "Encrypts ${local.name_prefix} EKS control plane logs"
  deletion_window_in_days = var.cluster_kms_deletion_window_in_days
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

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-eks-logs-kms" })
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${local.name_prefix}-eks-logs"
  target_key_id = aws_kms_key.logs.key_id
}
