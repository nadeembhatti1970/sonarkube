# ---------------------------------------------------------------------------
# Integration test: plans the application stack with an internal ALB ingress,
# larger resources and a faster ESO refresh interval.
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

  ingress_enabled     = true
  ingress_class_name  = "alb"
  ingress_host        = "sonarqube.dev.sonarkube.internal"
  ingress_annotations = { "alb.ingress.kubernetes.io/certificate-arn" = "arn:aws:acm:eu-west-1:123456789012:certificate/abc" }

  cpu_limit        = "4"
  memory_limit     = "12Gi"
  persistence_size = "100Gi"

  external_secrets_refresh_interval = "15m"
}

run "ingress_resources_and_refresh_render" {
  command = plan

  assert {
    condition     = output.ingress_host == "sonarqube.dev.sonarkube.internal"
    error_message = "The ingress host must be exported for DNS automation."
  }

  assert {
    condition     = strcontains(yamlencode(local.helm_values), "\"ingressClassName\": \"alb\"")
    error_message = "The ingress class must be rendered into the Helm values."
  }

  assert {
    condition     = strcontains(yamlencode(local.helm_values), "sonarqube.dev.sonarkube.internal")
    error_message = "The ingress host must be rendered into the Helm values."
  }

  assert {
    condition     = strcontains(yamlencode(local.helm_values), "certificate-arn")
    error_message = "User supplied ALB annotations must be merged into the ingress annotations."
  }

  assert {
    condition     = strcontains(yamlencode(local.helm_values), "\"size\": \"100Gi\"")
    error_message = "The persistence size must be configurable per environment."
  }

  assert {
    condition     = strcontains(yamlencode(local.eso_values), "\"refreshInterval\": \"15m\"")
    error_message = "The ESO refresh interval must be configurable per environment."
  }
}
