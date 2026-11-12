# ---------------------------------------------------------------------------
# Dev environment inputs for core-secretsmanager.
#
#   terraform init -backend-config=dev.tfbackend
#   terraform plan  -var-file=dev.tfvars
#   terraform apply -var-file=dev.tfvars
#
# No password is present here: everything is generated as an ephemeral value
# and written with write-only arguments, so nothing lands in Terraform state.
# ---------------------------------------------------------------------------

project     = "sonarkube"
environment = "dev"
aws_region  = "eu-west-1"

state_bucket_name = "sonarkube-dev-eu-west-1-tfstate"
state_key_prefix  = "environments"

secret_recovery_window_in_days = 30
kms_deletion_window_in_days    = 30

sonarqube_admin_password_length = 32

# Bump this to rotate the admin password, monitoring passcode and server
# encryption key. New values are generated ephemerally and written write-only;
# External Secrets Operator refreshes the cluster within its interval and the
# SonarQube pod is restarted to rebuild its connection pool.
sonarqube_credentials_version = 1

enable_rds_master_rotation     = false
rds_master_rotation_lambda_arn = null
rds_master_rotation_days       = 30

tags = {
  Owner      = "platform-engineering"
  CostCenter = "engineering-platform"
  DataClass  = "confidential"
}
