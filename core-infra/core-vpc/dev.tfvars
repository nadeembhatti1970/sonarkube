# ---------------------------------------------------------------------------
# Dev environment inputs for core-vpc.
#
#   terraform init -backend-config=dev.tfbackend
#   terraform plan -var-file=dev.tfvars
#   terraform apply -var-file=dev.tfvars
# ---------------------------------------------------------------------------

project     = "sonarkube"
environment = "dev"
aws_region  = "eu-west-1"

state_bucket_name = "sonarkube-dev-eu-west-1-tfstate"
state_key_prefix  = "environments"

vpc_cidr = "10.20.0.0/16"

azs = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

public_subnets = [
  "10.20.0.0/20",
  "10.20.16.0/20",
  "10.20.32.0/20",
]

private_subnets = [
  "10.20.48.0/20",
  "10.20.64.0/20",
  "10.20.80.0/20",
]

database_subnets = [
  "10.20.96.0/24",
  "10.20.97.0/24",
  "10.20.98.0/24",
]

enable_nat_gateway     = true
one_nat_gateway_per_az = true
create_vpc_endpoints   = true

flow_log_retention_in_days = 365

tags = {
  Owner      = "platform-engineering"
  CostCenter = "engineering-platform"
  DataClass  = "internal"
}
