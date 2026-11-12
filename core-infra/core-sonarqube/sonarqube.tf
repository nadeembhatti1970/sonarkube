# ---------------------------------------------------------------------------
# SonarQube Community Build via the official SonarSource Helm chart.
#
# The chart is pinned to an exact version and every environment specific value
# is injected here. Credentials are referenced by Kubernetes secret name only:
# no password, JDBC credential or passcode ever appears in Helm values.
# ---------------------------------------------------------------------------
locals {
  ingress_values = {
    enabled          = var.ingress_enabled
    ingressClassName = var.ingress_class_name

    hosts = [
      {
        name     = var.ingress_host
        path     = "/"
        pathType = "Prefix"
      }
    ]

    annotations = merge(
      {
        "alb.ingress.kubernetes.io/scheme"                       = "internal"
        "alb.ingress.kubernetes.io/target-type"                  = "ip"
        "alb.ingress.kubernetes.io/backend-protocol"             = "HTTP"
        "alb.ingress.kubernetes.io/healthcheck-path"             = "/api/system/status"
        "alb.ingress.kubernetes.io/healthcheck-interval-seconds" = "30"
        "alb.ingress.kubernetes.io/healthcheck-timeout-seconds"  = "10"
        "alb.ingress.kubernetes.io/healthy-threshold-count"      = "2"
        "alb.ingress.kubernetes.io/unhealthy-threshold-count"    = "3"
        "alb.ingress.kubernetes.io/success-codes"                = "200"
        "alb.ingress.kubernetes.io/listen-ports"                 = "[{\"HTTP\":80}]"
      },
      var.ingress_annotations,
    )

    tls = var.ingress_tls_secret_name == null ? [] : [
      {
        secretName = var.ingress_tls_secret_name
        hosts      = [var.ingress_host]
      }
    ]
  }

  base_values = {
    deploymentType = "StatefulSet"
    replicaCount   = 1

    # Chart >= 2026.5 requires an explicit edition choice. Community Build is
    # selected by enabling `community` and leaving `edition` unset.
    community = {
      enabled = true
    }

    image = {
      repository = "sonarqube"
      pullPolicy = "IfNotPresent"
    }

    # No API token is mounted into the payload; SonarQube does not call the
    # Kubernetes API.
    serviceAccount = {
      create         = true
      automountToken = false
    }

    service = {
      type         = var.service_type
      externalPort = 9000
      internalPort = 9000
    }

    ingress = local.ingress_values

    # External PostgreSQL (RDS). Username and URL are non-secret; the password
    # is read from the Kubernetes secret created from Secrets Manager.
    jdbcOverwrite = {
      enabled               = true
      jdbcUrl               = data.terraform_remote_state.rds.outputs.jdbc_url
      jdbcUsername          = data.terraform_remote_state.rds.outputs.db_username
      jdbcSecretName        = local.db_secret_name
      jdbcSecretPasswordKey = "password"
    }

    monitoringPasscodeSecretName = local.admin_secret_name
    monitoringPasscodeSecretKey  = "passcode"

    # Server-side encryption key for settings such as webhook/SCM tokens.
    sonarSecretKey = local.admin_secret_name

    # Set the local admin password from the managed secret on first boot.
    setAdminPassword = {
      passwordSecretName = local.admin_secret_name
    }

    persistence = {
      enabled      = true
      storageClass = var.storage_class_name
      accessMode   = "ReadWriteOnce"
      size         = var.persistence_size
      uid          = 1000
      guid         = 0
    }

    resources = {
      requests = {
        cpu    = var.cpu_request
        memory = var.memory_request
      }
      limits = {
        cpu    = var.cpu_limit
        memory = var.memory_limit
      }
    }

    securityContext = {
      fsGroup = 1000
    }

    # initSysctl raises vm.max_map_count / fs.file-max inside the pod; this is
    # why the namespace enforces the privileged Pod Security Standard.
    initSysctl = {
      enabled = true
    }

    initFs = {
      enabled = true
    }

    podLabels = var.pod_labels

    # Empty map when no extra properties are configured; Helm treats it as a
    # no-op and keeps the chart defaults.
    sonarProperties = var.sonar_properties

    # The chart's own smoke test requires an external HTTP client; disable it
    # so Helm installs are deterministic in air-gapped clusters.
    tests = {
      enabled = false
    }
  }

  helm_values = local.base_values
}

resource "helm_release" "sonarqube" {
  name       = "sonarqube"
  namespace  = var.namespace
  chart      = "sonarqube"
  repository = "https://SonarSource.github.io/helm-chart-sonarqube"
  version    = var.chart_version

  timeout         = var.helm_timeout_seconds
  wait            = true
  wait_for_jobs   = true
  atomic          = true
  cleanup_on_fail = true
  max_history     = 5

  values = [yamlencode(local.helm_values)]

  # External Secrets Operator creates sonarqube-db / sonarqube-admin from
  # Secrets Manager; install the SonarQube chart only after those
  # ExternalSecrets have been submitted.
  depends_on = [
    kubernetes_namespace_v1.sonarqube,
    kubernetes_storage_class_v1.ebs_gp3,
    helm_release.sonarqube_secrets,
  ]
}
