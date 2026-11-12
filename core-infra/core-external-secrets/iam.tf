# ---------------------------------------------------------------------------
# Controller identity.
#
# The External Secrets Operator runs with EKS Pod Identity: the controller
# service account is bound to an IAM role whose permissions are limited to the
# platform's own secrets and the key that encrypts them. No static AWS
# credentials are mounted, and no wildcard resource is allowed.
# ---------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "AllowEksPodIdentity"
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${local.name_prefix}-external-secrets"
  description        = "Reads platform secrets from AWS Secrets Manager for the ${local.name_prefix} cluster"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-external-secrets" })
}

data "aws_iam_policy_document" "read_secrets" {
  statement {
    sid    = "ReadPlatformSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds",
    ]
    resources = sort(values(data.terraform_remote_state.secretsmanager.outputs.secret_arns))
  }

  statement {
    sid    = "DecryptPlatformSecrets"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = [data.terraform_remote_state.secretsmanager.outputs.kms_key_arn]
  }
}

resource "aws_iam_policy" "read_secrets" {
  name        = "${local.name_prefix}-external-secrets-read"
  description = "Least-privilege Secrets Manager read access for the External Secrets Operator"
  policy      = data.aws_iam_policy_document.read_secrets.json

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-external-secrets-read" })
}

resource "aws_iam_role_policy_attachment" "read_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.read_secrets.arn
}

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = data.terraform_remote_state.eks.outputs.cluster_name
  namespace       = var.namespace
  service_account = var.service_account_name
  role_arn        = aws_iam_role.external_secrets.arn
}
