# ---------------------------------------------------------------------------
# Cross-stack inputs: cluster endpoint/CA from core-eks, JDBC details from
# core-rds and the SonarQube administrator credentials from
# core-secretsmanager.
# ---------------------------------------------------------------------------
data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = var.state_bucket_name
    key    = "${var.state_key_prefix}/${var.environment}/core-eks/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "rds" {
  backend = "s3"

  config = {
    bucket = var.state_bucket_name
    key    = "${var.state_key_prefix}/${var.environment}/core-rds/terraform.tfstate"
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
