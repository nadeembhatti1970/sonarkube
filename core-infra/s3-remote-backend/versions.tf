terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # ---------------------------------------------------------------------------
  # Bootstrap module: intentionally uses LOCAL state.
  #
  # This module creates the S3 bucket that every other root module uses as its
  # remote backend, so it cannot itself depend on that bucket. The resulting
  # terraform.tfstate is small (one bucket pair and one KMS key) and must be
  # stored somewhere durable by the operator (see README.md).
  # ---------------------------------------------------------------------------
}
