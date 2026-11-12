# ---------------------------------------------------------------------------
# Cross-stack inputs.
#   core-eks             -> cluster endpoint/CA/name for the Helm provider
#   core-secretsmanager  -> exact secret ARNs and the CMK ARN, so the
#                           controller policy is least-privilege
# ---------------------------------------------------------------------------
data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = var.state_bucket_name
    key    = "${var.state_key_prefix}/${var.environment}/core-eks/terraform.tfstate"
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
