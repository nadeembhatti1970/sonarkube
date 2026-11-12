# ---------------------------------------------------------------------------
# Cross-stack inputs.
#
# core-eks consumes the private subnets and the shared database-clients
# security group from the network stack, and writes the cluster kubeconfig
# into the secret created by core-secretsmanager.
# ---------------------------------------------------------------------------
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = var.state_bucket_name
    key    = "${var.state_key_prefix}/${var.environment}/core-vpc/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "secretsmanager" {
  backend = "s3"

  config = {
    bucket = var.state_bucket_name
    key    = "${var.state_key_prefix}/${var.environment}/core-secretsmanager/terraform.tfstate"
    region = var.aws_region
  }
}
