# ---------------------------------------------------------------------------
# Dev environment inputs for core-external-secrets.
#
#   terraform init -backend-config=dev.tfbackend
#   terraform plan  -var-file=dev.tfvars
#   terraform apply -var-file=dev.tfvars
#
# Apply after core-eks and core-secretsmanager, before core-sonarqube.
# ---------------------------------------------------------------------------

project     = "sonarkube"
environment = "dev"
aws_region  = "eu-west-1"

state_bucket_name = "sonarkube-dev-eu-west-1-tfstate"
state_key_prefix  = "environments"

namespace            = "external-secrets"
service_account_name = "external-secrets"

chart_version = "2.15.0"
replica_count = 1

secret_store_name = "aws-secretsmanager"

helm_timeout_seconds = 600

tags = {
  Owner      = "platform-engineering"
  CostCenter = "engineering-platform"
  DataClass  = "internal"
}
