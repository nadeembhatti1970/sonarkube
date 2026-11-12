# ---------------------------------------------------------------------------
# Unit tests: controller identity, least-privilege policy and Helm wiring.
# ---------------------------------------------------------------------------
mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"pods.eks.amazonaws.com\"},\"Action\":[\"sts:AssumeRole\",\"sts:TagSession\"]}]}"
    }
  }
}

mock_provider "helm" {}

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
  target = data.terraform_remote_state.secretsmanager
  values = {
    outputs = {
      kms_key_arn = "arn:aws:kms:eu-west-1:123456789012:key/11111111-2222-3333-4444-555555555555"
      secret_arns = {
        rds_master                       = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:sonarkube-dev/rds/master-AbCdEf"
        sonarqube_database               = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:sonarkube-dev/sonarqube/database-AbCdEf"
        sonarqube_admin_password         = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:sonarkube-dev/sonarqube/admin-password-AbCdEf"
        sonarqube_admin_current_password = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:sonarkube-dev/sonarqube/admin-current-password-AbCdEf"
        sonarqube_monitoring_passcode    = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:sonarkube-dev/sonarqube/monitoring-passcode-AbCdEf"
        sonarqube_server_secret_key      = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:sonarkube-dev/sonarqube/server-secret-key-AbCdEf"
        kubernetes_kubeconfig            = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:sonarkube-dev/kubernetes/kubeconfig-AbCdEf"
      }
    }
  }
}

variables {
  project     = "sonarkube"
  environment = "dev"
  aws_region  = "eu-west-1"

  state_bucket_name = "sonarkube-dev-eu-west-1-tfstate"
}

run "controller_identity_is_pod_identity_scoped" {
  command = plan

  assert {
    condition     = aws_iam_role.external_secrets.name == "sonarkube-dev-external-secrets"
    error_message = "The controller must use a dedicated IAM role."
  }

  assert {
    condition     = aws_eks_pod_identity_association.external_secrets.namespace == "external-secrets"
    error_message = "Pod Identity must be bound to the ESO namespace."
  }

  assert {
    condition     = aws_eks_pod_identity_association.external_secrets.service_account == "external-secrets"
    error_message = "Pod Identity must be bound to the ESO service account."
  }

  assert {
    condition     = aws_eks_pod_identity_association.external_secrets.cluster_name == "sonarkube-dev-eks"
    error_message = "Pod Identity must target the platform cluster."
  }

  assert {
    condition     = aws_iam_policy.read_secrets.name == "sonarkube-dev-external-secrets-read"
    error_message = "The controller policy must be a dedicated least-privilege policy."
  }
}

run "operator_is_pinned" {
  command = plan

  assert {
    condition     = helm_release.external_secrets.chart == "external-secrets"
    error_message = "The official ESO chart must be used."
  }

  assert {
    condition     = helm_release.external_secrets.version == "2.15.0"
    error_message = "The ESO chart version must be pinned."
  }

  assert {
    condition     = helm_release.external_secrets.namespace == "external-secrets"
    error_message = "ESO must run in its dedicated namespace."
  }

  assert {
    condition     = helm_release.external_secrets.create_namespace
    error_message = "The ESO namespace must be created by the release."
  }
}

run "cluster_secret_store_is_installed" {
  command = plan

  assert {
    condition     = strcontains(helm_release.secret_store.chart, "helm/external-secrets-store")
    error_message = "The store must be installed from the in-repo chart."
  }

  assert {
    condition     = helm_release.secret_store.name == "external-secrets-store"
    error_message = "The store release must be discoverable by name."
  }
}

run "rejects_unpinned_chart_version" {
  command = plan

  variables {
    chart_version = "latest"
  }

  expect_failures = [var.chart_version]
}

run "rejects_invalid_namespace" {
  command = plan

  variables {
    namespace = "External_Secrets"
  }

  expect_failures = [var.namespace]
}
