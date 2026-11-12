# ---------------------------------------------------------------------------
# Kubernetes access bundle.
#
# core-eks writes a kubeconfig that authenticates with `aws eks get-token`
# (short-lived STS tokens, no static credentials). Storing the kubeconfig here
# gives CI/CD and operators a single, auditable location to fetch it from and
# avoids long-lived cluster tokens entirely.
# ---------------------------------------------------------------------------
#checkov:skip=CKV2_AWS_57:Kubeconfig contains no long-lived secret; authentication is delegated to aws eks get-token, so rotation is inherent.
resource "aws_secretsmanager_secret" "kubernetes_kubeconfig" {
  name                    = local.secret_names.kubernetes_kubeconfig
  description             = "Kubeconfig for the ${local.name_prefix} EKS cluster (exec auth via aws eks get-token)"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = var.secret_recovery_window_in_days

  tags = merge(local.common_tags, { Name = local.secret_names.kubernetes_kubeconfig })
}
