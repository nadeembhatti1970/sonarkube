# ---------------------------------------------------------------------------
# Dev environment inputs for the Terraform state bootstrap module.
#
#   terraform init
#   terraform plan  -var-file=dev.tfvars
#   terraform apply -var-file=dev.tfvars
#
# The state bucket name must be globally unique; replace it if the default is
# already taken in your AWS account.
# ---------------------------------------------------------------------------

project     = "sonarkube"
environment = "dev"
aws_region  = "eu-west-1"

state_bucket_name             = "sonarkube-dev-eu-west-1-tfstate"
state_access_logs_bucket_name = "sonarkube-dev-eu-west-1-tfstate-access-logs"

kms_deletion_window_in_days        = 30
noncurrent_version_expiration_days = 90

tags = {
  Owner      = "platform-engineering"
  CostCenter = "engineering-platform"
  DataClass  = "confidential"
}
