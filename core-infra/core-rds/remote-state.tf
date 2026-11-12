# ---------------------------------------------------------------------------
# Cross-stack inputs are read from the remote state of the modules that own
# them. This keeps a single source of truth for the network and for secrets
# and avoids copy/pasting resource IDs between environments.
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
