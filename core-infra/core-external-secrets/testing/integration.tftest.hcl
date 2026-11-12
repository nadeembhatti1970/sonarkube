# ---------------------------------------------------------------------------
# Integration test: plans the controller with a larger replica count and a
# custom store name.
# ---------------------------------------------------------------------------
mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"pods.eks.amazonaws.com\"},\"Action\":[\"sts:AssumeRole\",\"sts:TagSession\"]}]}"
    }
  }
}

mock_provider "helm" {}

override_data {
  target = data.terraform_remote_state.eks
  values = {
    outputs = {
      cluster_name                       = "sonarkube-dev-eks"
      cluster_endpoint                   = "https://example.gr7.eu-west-1.eks.amazonaws.com"
      cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"
    }
  }
}

override_data {
  target = data.terraform_remote_state.secretsmanager
  values = {
    outputs = {
      kms_key_arn = "arn:aws:kms:eu-west-1:123456789012:key/11111111-2222-3333-4444-555555555555"
      secret_arns = {
        sonarqube_database = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:sonarkube-dev/sonarqube/database-AbCdEf"
      }
    }
  }
}

variables {
  project     = "sonarkube"
  environment = "dev"
  aws_region  = "eu-west-1"

  state_bucket_name = "sonarkube-dev-eu-west-1-tfstate"

  replica_count     = 2
  secret_store_name = "platform-secrets"
}

run "controller_plans_with_custom_store" {
  command = plan

  assert {
    condition     = output.secret_store_name == "platform-secrets"
    error_message = "The store name must be exported for application modules."
  }

  assert {
    condition     = output.namespace == "external-secrets"
    error_message = "The controller namespace must be exported."
  }

  assert {
    condition     = output.service_account_name == "external-secrets"
    error_message = "The controller service account must be exported."
  }
}
