# ---------------------------------------------------------------------------
# Integration test: exercises the full resource lifecycle with mocked AWS
# providers. Catches dependency cycles, invalid references and apply-time
# configuration errors without creating real infrastructure.
# ---------------------------------------------------------------------------
mock_provider "aws" {}

variables {
  project                       = "sonarkube"
  environment                   = "dev"
  aws_region                    = "eu-west-1"
  state_bucket_name             = "sonarkube-dev-eu-west-1-tfstate"
  state_access_logs_bucket_name = "sonarkube-dev-eu-west-1-tfstate-access-logs"
}

run "bootstrap_applies_cleanly" {
  command = apply

  assert {
    condition     = aws_s3_bucket.tfstate.bucket == "sonarkube-dev-eu-west-1-tfstate"
    error_message = "State bucket was not created with the expected name."
  }

  assert {
    condition     = aws_kms_alias.tfstate.name == "alias/sonarkube-dev-tfstate"
    error_message = "KMS alias must match the value referenced by dev.tfbackend."
  }

  assert {
    condition     = output.backend_configuration.use_lockfile == true
    error_message = "Backend configuration must advertise native S3 locking."
  }
}
