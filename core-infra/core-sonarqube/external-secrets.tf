# ---------------------------------------------------------------------------
# External secrets for SonarQube.
#
# Terraform does not read or write credential material here. It installs a
# small chart containing two ExternalSecret resources; External Secrets
# Operator (installed by core-external-secrets) reads AWS Secrets Manager and
# maintains the Kubernetes Secrets:
#
#   sonarqube-db      host, port, database, username, password, sslmode,
#                     jdbc_url, engine (extracted from the core-rds JSON)
#   sonarqube-admin   password, currentPassword, passcode, sonar-secret.txt
#
# Rotation happens in AWS: ESO re-reads the secrets every refreshInterval, so
# `sonarqube_credentials_version` / `db_password_revision` bumps propagate
# without a Terraform-managed Kubernetes secret.
# ---------------------------------------------------------------------------
locals {
  db_secret_name    = "sonarqube-db"
  admin_secret_name = "sonarqube-admin"

  eso_values = {
    namespace       = var.namespace
    storeName       = var.external_secrets_store_name
    refreshInterval = var.external_secrets_refresh_interval

    database = {
      secretName = data.terraform_remote_state.secretsmanager.outputs.sonarqube_database_secret_name
      targetName = local.db_secret_name
    }

    admin = {
      passwordSecretName           = data.terraform_remote_state.secretsmanager.outputs.sonarqube_admin_password_secret_name
      currentPasswordSecretName    = data.terraform_remote_state.secretsmanager.outputs.sonarqube_admin_current_password_secret_name
      monitoringPasscodeSecretName = data.terraform_remote_state.secretsmanager.outputs.sonarqube_monitoring_passcode_secret_name
      serverSecretKeySecretName    = data.terraform_remote_state.secretsmanager.outputs.sonarqube_server_secret_key_secret_name
      targetName                   = local.admin_secret_name
    }
  }
}

resource "helm_release" "sonarqube_secrets" {
  name      = "sonarqube-secrets"
  namespace = var.namespace

  chart = "${path.module}/../../helm/sonarqube-secrets"

  timeout         = var.helm_timeout_seconds
  wait            = true
  atomic          = true
  cleanup_on_fail = true
  max_history     = 5

  values = [yamlencode(local.eso_values)]

  depends_on = [kubernetes_namespace_v1.sonarqube]
}
