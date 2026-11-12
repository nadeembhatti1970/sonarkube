# ---------------------------------------------------------------------------
# Customer managed KMS key used for Terraform state objects and access logs.
#
# A dedicated key (instead of the AWS managed aws/s3 key) gives the platform
# team independent control over key rotation, key policy and cryptographically
# shredding historical state if the bucket is ever decommissioned.
# ---------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

resource "aws_kms_key" "tfstate" {
  description             = "Encrypts Terraform remote state and access logs for ${local.name_prefix}"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true
  multi_region            = false

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
        Sid    = "AllowS3AccessLogDelivery"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
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

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-tfstate-kms" })
}

resource "aws_kms_alias" "tfstate" {
  name          = "alias/${local.name_prefix}-tfstate"
  target_key_id = aws_kms_key.tfstate.key_id
}
