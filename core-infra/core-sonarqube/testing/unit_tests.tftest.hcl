# ---------------------------------------------------------------------------
# Unit tests: namespace, storage and the External Secrets wiring.
#
# No AWS provider is required any more: Terraform never reads credential
# material. Helm and Kubernetes are mocked, remote-state contracts are pinned.
# ---------------------------------------------------------------------------
mock_provider "helm" {}
mock_provider "kubernetes" {}

override_data {
  target = data.terraform_remote_state.eks
  values = {
    outputs = {
      cluster_name                       = "sonarkube-dev-eks"
      cluster_endpoint                   = "https://example.gr7.eu-west-1.eks.amazonaws.com"
      cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"
    }
  }
}

override_data {
  target = data.terraform_remote_state.rds
  values = {
    outputs = {
      db_instance_address = "sonarqube-db.eu-west-1.rds.amazonaws.com"
      db_instance_port    = 5432
      db_name             = "sonarqube"
      db_username         = "sonar_admin"
      sslmode             = "require"
      jdbc_url            = "jdbc:postgresql://sonarqube-db.eu-west-1.rds.amazonaws.com:5432/sonarqube?sslmode=require"
    }
  }
}

override_data {
  target = data.terraform_remote_state.secretsmanager
  values = {
    outputs = {
      sonarqube_database_secret_name               = "sonarkube-dev/sonarqube/database"
      sonarqube_admin_password_secret_name         = "sonarkube-dev/sonarqube/admin-password"
      sonarqube_admin_current_password_secret_name = "sonarkube-dev/sonarqube/admin-current-password"
      sonarqube_monitoring_passcode_secret_name    = "sonarkube-dev/sonarqube/monitoring-passcode"
      sonarqube_server_secret_key_secret_name      = "sonarkube-dev/sonarqube/server-secret-key"
    }
  }
}

variables {
  project     = "sonarkube"
  environment = "dev"
  aws_region  = "eu-west-1"

  state_bucket_name = "sonarkube-dev-eu-west-1-tfstate"
}

run "namespace_and_storage_are_created" {
  command = plan

  assert {
    condition     = kubernetes_namespace_v1.sonarqube.metadata[0].name == "sonarqube"
    error_message = "SonarQube must run in its dedicated namespace."
  }

  assert {
    condition     = kubernetes_storage_class_v1.ebs_gp3.storage_provisioner == "ebs.csi.aws.com"
    error_message = "Persistent storage must use the EBS CSI driver."
  }

  assert {
    condition     = kubernetes_storage_class_v1.ebs_gp3.parameters["encrypted"] == "true"
    error_message = "SonarQube volumes must be encrypted at rest."
  }

  assert {
    condition     = kubernetes_storage_class_v1.ebs_gp3.volume_binding_mode == "WaitForFirstConsumer"
    error_message = "The gp3 class must bind volumes in the pod's AZ."
  }
}

run "external_secrets_are_wired" {
  command = plan

  assert {
    condition     = strcontains(helm_release.sonarqube_secrets.chart, "helm/sonarqube-secrets")
    error_message = "The ExternalSecret chart must be installed from this repository."
  }

  assert {
    condition     = strcontains(yamlencode(local.eso_values), "\"storeName\": \"aws-secretsmanager\"")
    error_message = "The ExternalSecrets must reference the platform ClusterSecretStore."
  }

  assert {
    condition     = strcontains(yamlencode(local.eso_values), "\"secretName\": \"sonarkube-dev/sonarqube/database\"")
    error_message = "The database ExternalSecret must read the core-rds JSON secret."
  }

  assert {
    condition     = strcontains(yamlencode(local.eso_values), "\"passwordSecretName\": \"sonarkube-dev/sonarqube/admin-password\"")
    error_message = "The admin ExternalSecret must read the managed administrator password."
  }

  assert {
    condition     = strcontains(yamlencode(local.eso_values), "\"currentPasswordSecretName\": \"sonarkube-dev/sonarqube/admin-current-password\"")
    error_message = "The chart hook needs the previous administrator password from Secrets Manager."
  }
}

run "helm_release_is_pinned_and_secret_aware" {
  command = plan

  assert {
    condition     = helm_release.sonarqube.chart == "sonarqube"
    error_message = "The official SonarSource chart must be used."
  }

  assert {
    condition     = local.base_values.community.enabled
    error_message = "The chart requires community.enabled=true for the Community Build."
  }

  assert {
    condition     = helm_release.sonarqube.version == "2026.5.1004"
    error_message = "The chart version must be pinned."
  }

  assert {
    condition     = helm_release.sonarqube.namespace == "sonarqube"
    error_message = "The release must be installed into the SonarQube namespace."
  }

  assert {
    condition     = output.service_name == "sonarqube-sonarqube"
    error_message = "The Service name must follow the Helm fullname (<release>-<chart>)."
  }

  assert {
    condition     = helm_release.sonarqube.atomic && helm_release.sonarqube.wait
    error_message = "Helm installs must be atomic and wait for readiness."
  }

  assert {
    condition = strcontains(yamlencode(local.helm_values),
    "jdbc:postgresql://sonarqube-db.eu-west-1.rds.amazonaws.com:5432/sonarqube?sslmode=require")
    error_message = "The Helm values must point SonarQube at the RDS JDBC endpoint."
  }

  assert {
    condition     = strcontains(yamlencode(local.helm_values), "\"jdbcSecretName\": \"sonarqube-db\"")
    error_message = "The JDBC password must be referenced by secret name, never inlined."
  }
}

run "ingress_is_disabled_by_default" {
  command = plan

  assert {
    condition     = var.ingress_enabled == false
    error_message = "Ingress must be opt-in because it requires an installed controller."
  }

  assert {
    condition     = output.ingress_host == null
    error_message = "No host may be published when ingress is disabled."
  }
}

run "rejects_unpinned_chart_version" {
  command = plan

  variables {
    chart_version = "latest"
  }

  expect_failures = [var.chart_version]
}

run "rejects_invalid_refresh_interval" {
  command = plan

  variables {
    external_secrets_refresh_interval = "hourly"
  }

  expect_failures = [var.external_secrets_refresh_interval]
}

run "rejects_unqualified_storage_size" {
  command = plan

  variables {
    persistence_size = "20"
  }

  expect_failures = [var.persistence_size]
}
