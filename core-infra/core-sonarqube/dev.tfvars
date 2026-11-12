# ---------------------------------------------------------------------------
# Dev environment inputs for core-sonarqube.
#
#   terraform init -backend-config=dev.tfbackend
#   terraform plan -var-file=dev.tfvars
#   terraform apply -var-file=dev.tfvars
#
# Requires the core-eks, core-rds and core-secretsmanager states to exist, and
# network access to the private EKS endpoint.
# ---------------------------------------------------------------------------

project     = "sonarkube"
environment = "dev"
aws_region  = "eu-west-1"

state_bucket_name = "sonarkube-dev-eu-west-1-tfstate"
state_key_prefix  = "environments"

namespace     = "sonarqube"
chart_version = "2026.5.1004"

helm_timeout_seconds = 900

storage_class_name        = "ebs-gp3"
set_default_storage_class = true
persistence_size          = "20Gi"

cpu_request    = "1"
cpu_limit      = "2"
memory_request = "4Gi"
memory_limit   = "8Gi"

# External Secrets Operator store installed by core-external-secrets.
external_secrets_store_name       = "aws-secretsmanager"
external_secrets_refresh_interval = "1h"

service_type = "ClusterIP"

# The ALB controller is not part of this stack. Install it first, then set
# ingress_enabled = true and provide the ACM certificate annotation.
ingress_enabled     = false
ingress_class_name  = "alb"
ingress_host        = "sonarqube.dev.sonarkube.internal"
ingress_annotations = {}

# Do not set sonar.forceAuthentication here: the fixer Job in
# kubernetes/sonarqube-db-fixer demonstrates changing that setting in place.
sonar_properties = {}

tags = {
  Owner      = "platform-engineering"
  CostCenter = "engineering-platform"
  DataClass  = "internal"
}
