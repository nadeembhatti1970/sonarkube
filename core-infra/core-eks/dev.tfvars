# ---------------------------------------------------------------------------
# Dev environment inputs for core-eks.
#
#   terraform init -backend-config=dev.tfbackend
#   terraform plan -var-file=dev.tfvars
#   terraform apply -var-file=dev.tfvars
#
# The API endpoint is private only. Terraform Apply and kubectl/helm must run
# from inside the VPC (VPN, SSM port-forward or a VPC-attached CI runner).
# ---------------------------------------------------------------------------

project     = "sonarkube"
environment = "dev"
aws_region  = "eu-west-1"

state_bucket_name = "sonarkube-dev-eu-west-1-tfstate"
state_key_prefix  = "environments"

kubernetes_version = "1.34"

cluster_endpoint_public_access       = false
cluster_endpoint_public_access_cidrs = []
cluster_log_retention_in_days        = 365
cluster_kms_deletion_window_in_days  = 30

node_instance_types = ["m6i.large"]
node_capacity_type  = "ON_DEMAND"
node_min_size       = 3
node_desired_size   = 3
node_max_size       = 6
node_disk_size      = 100

# Populate with the ARNs of the human break-glass and CI/CD deploy roles.
cluster_admin_role_arns  = []
cluster_editor_role_arns = []

tags = {
  Owner      = "platform-engineering"
  CostCenter = "engineering-platform"
  DataClass  = "internal"
}
