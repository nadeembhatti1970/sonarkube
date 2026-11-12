# ---------------------------------------------------------------------------
# Unit tests: state bucket guard rails and input validation.
# Providers are mocked, so this suite runs offline and never touches AWS.
# ---------------------------------------------------------------------------
mock_provider "aws" {}

variables {
  project                       = "sonarkube"
  environment                   = "dev"
  aws_region                    = "eu-west-1"
  state_bucket_name             = "sonarkube-dev-eu-west-1-tfstate"
  state_access_logs_bucket_name = "sonarkube-dev-eu-west-1-tfstate-access-logs"
}

run "state_bucket_is_locked_down" {
  command = plan

  assert {
    condition     = aws_s3_bucket.tfstate.bucket == var.state_bucket_name
    error_message = "The state bucket name must come from state_bucket_name."
  }

  assert {
    condition     = aws_s3_bucket_versioning.tfstate.versioning_configuration[0].status == "Enabled"
    error_message = "State bucket versioning must be enabled so previous state can be recovered."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.tfstate.block_public_acls && aws_s3_bucket_public_access_block.tfstate.block_public_policy && aws_s3_bucket_public_access_block.tfstate.ignore_public_acls && aws_s3_bucket_public_access_block.tfstate.restrict_public_buckets
    error_message = "All four public access blocks must be enabled on the state bucket."
  }

  assert {
    condition = length([
      for rule in aws_s3_bucket_server_side_encryption_configuration.tfstate.rule : rule
      if rule.apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"
    ]) == 1
    error_message = "State objects must be encrypted with a customer managed KMS key."
  }

  assert {
    condition     = aws_s3_bucket.tfstate.force_destroy == false
    error_message = "force_destroy must stay false so a destroy fails loudly instead of deleting history."
  }

  assert {
    condition     = aws_kms_key.tfstate.enable_key_rotation
    error_message = "The state KMS key must rotate annually."
  }

  assert {
    condition     = aws_s3_bucket_logging.tfstate.target_bucket == var.state_access_logs_bucket_name
    error_message = "Server access logging must be delivered to the dedicated logs bucket."
  }
}

run "access_logs_bucket_expires_objects" {
  command = plan

  assert {
    condition = length([
      for rule in aws_s3_bucket_lifecycle_configuration.state_access_logs.rule : rule
      if rule.expiration[0].days == 365
    ]) == 1
    error_message = "Access logs must expire after 365 days."
  }
}

run "rejects_unmanaged_environment" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}

run "rejects_short_noncurrent_retention" {
  command = plan

  variables {
    noncurrent_version_expiration_days = 7
  }

  expect_failures = [var.noncurrent_version_expiration_days]
}
