# ---------------------------------------------------------------------------
# Integration test: plans the complete secret inventory (containers only plus
# write-only versions) without contacting AWS.
# ---------------------------------------------------------------------------
mock_provider "aws" {}

variables {
  project     = "sonarkube"
  environment = "dev"
  aws_region  = "eu-west-1"

  state_bucket_name = "sonarkube-dev-eu-west-1-tfstate"

  enable_rds_master_rotation     = true
  rds_master_rotation_lambda_arn = "arn:aws:lambda:eu-west-1:123456789012:function:rotate-rds"
}

run "secret_inventory_plans" {
  command = plan

  assert {
    condition     = output.kms_key_alias == "alias/sonarkube-dev-secrets"
    error_message = "The secrets key alias must be stable for IAM policy references."
  }

  assert {
    condition     = length(output.secret_arns) == 7
    error_message = "The stack must publish the seven application secret containers."
  }

  assert {
    condition     = contains(keys(output.secret_arns), "sonarqube_admin_current_password")
    error_message = "The password-only database secret must be part of the published inventory."
  }
}
