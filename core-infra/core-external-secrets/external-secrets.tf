# ---------------------------------------------------------------------------
# External Secrets Operator.
#
# Installed with CRDs, then the ClusterSecretStore is applied by a small
# in-repo chart (Helm applies CRs at runtime, so there is no plan-time CRD
# discovery problem). The store uses the controller's Pod Identity, so it has
# no auth block at all.
# ---------------------------------------------------------------------------
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  namespace        = var.namespace
  create_namespace = true

  chart      = "external-secrets"
  repository = "https://charts.external-secrets.io"
  version    = var.chart_version

  timeout         = var.helm_timeout_seconds
  wait            = true
  atomic          = true
  cleanup_on_fail = true
  max_history     = 5

  values = [
    yamlencode({
      installCRDs  = true
      replicaCount = var.replica_count

      serviceAccount = {
        create    = true
        name      = var.service_account_name
        automount = true
      }

      resources = {
        requests = {
          cpu    = "50m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "250m"
          memory = "512Mi"
        }
      }

      podLabels = {
        "app.kubernetes.io/part-of" = "code-quality-platform"
      }
    })
  ]
}

resource "helm_release" "secret_store" {
  name      = "external-secrets-store"
  namespace = var.namespace

  chart = "${path.module}/../../helm/external-secrets-store"

  timeout         = var.helm_timeout_seconds
  wait            = true
  atomic          = true
  cleanup_on_fail = true
  max_history     = 5

  values = [
    yamlencode({
      name   = var.secret_store_name
      region = var.aws_region
    })
  ]

  depends_on = [helm_release.external_secrets]
}
