# ---------------------------------------------------------------------------
# Secrets Manager KMS key.
#
# One customer managed key encrypts every application secret in this
# environment. The key policy grants administration to the account root only,
# so access is entirely governed by IAM (IRSA roles, CI roles, break-glass).
# ---------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

resource "aws_kms_key" "secrets" {
  description             = "Encrypts application secrets for ${local.name_prefix}"
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
      }
    ]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-secrets-kms" })
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${local.name_prefix}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}
