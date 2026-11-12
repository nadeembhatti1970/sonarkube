# ---------------------------------------------------------------------------
# Integration test: applies the complete network stack against mocked
# providers, verifying that the module graph (VPC module, KMS key, endpoints,
# security groups) resolves without cycles or unknown-value errors.
# ---------------------------------------------------------------------------
mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"vpc-flow-logs.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    }
  }
}

variables {
  project     = "sonarkube"
  environment = "dev"
  aws_region  = "eu-west-1"

  state_bucket_name = "sonarkube-dev-eu-west-1-tfstate"

  vpc_cidr = "10.20.0.0/16"
  azs      = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

  public_subnets   = ["10.20.0.0/20", "10.20.16.0/20", "10.20.32.0/20"]
  private_subnets  = ["10.20.48.0/20", "10.20.64.0/20", "10.20.80.0/20"]
  database_subnets = ["10.20.96.0/24", "10.20.97.0/24", "10.20.98.0/24"]

  flow_log_retention_in_days = 90
}

run "network_stack_plans" {
  command = plan

  assert {
    condition     = output.vpc_cidr == "10.20.0.0/16"
    error_message = "The VPC CIDR output must match the input."
  }

  assert {
    condition     = output.database_subnet_group_name == "sonarkube-dev-db"
    error_message = "RDS must receive the subnet group created by the VPC module."
  }

  assert {
    condition     = aws_security_group.database_clients.name == "sonarkube-dev-database-clients"
    error_message = "The database-clients security group must be exported for RDS and EKS."
  }

  assert {
    condition     = aws_vpc_endpoint.interface["secretsmanager"].private_dns_enabled
    error_message = "Interface endpoints must enable private DNS so SDK calls resolve inside the VPC."
  }
}
