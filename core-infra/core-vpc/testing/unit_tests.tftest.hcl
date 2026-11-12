# ---------------------------------------------------------------------------
# Unit tests: three-tier network layout, isolation defaults and input
# validation. Providers are mocked, so the suite is offline and side-effect
# free.
# ---------------------------------------------------------------------------
mock_provider "aws" {
  # The VPC module builds IAM policy documents internally; mocks return random
  # strings, so pin a valid policy JSON for every aws_iam_policy_document read.
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
}

run "vpc_has_three_tiers" {
  command = plan

  assert {
    condition     = module.vpc.name == "sonarkube-dev-vpc"
    error_message = "The VPC must follow the <project>-<environment>-vpc naming convention."
  }

  assert {
    condition     = module.vpc.vpc_cidr_block == var.vpc_cidr
    error_message = "The VPC must be created with the configured CIDR."
  }

  assert {
    condition     = aws_security_group.database_clients.name == "sonarkube-dev-database-clients"
    error_message = "The shared database-clients security group must be created by the network layer."
  }
}

run "gateway_endpoints_exist" {
  command = plan

  assert {
    condition     = aws_vpc_endpoint.s3[0].vpc_endpoint_type == "Gateway"
    error_message = "S3 traffic must use a gateway endpoint to avoid NAT charges."
  }

  assert {
    condition     = aws_vpc_endpoint.dynamodb[0].service_name == "com.amazonaws.eu-west-1.dynamodb"
    error_message = "The DynamoDB gateway endpoint must target the configured region."
  }

  assert {
    condition     = length(aws_vpc_endpoint.interface) == 12
    error_message = "Every default interface endpoint service must receive an endpoint."
  }
}

run "flow_logs_are_encrypted" {
  command = plan

  assert {
    condition     = aws_kms_key.flow_logs.enable_key_rotation
    error_message = "The flow log key must rotate."
  }

  assert {
    condition     = aws_kms_key.flow_logs.deletion_window_in_days == 30
    error_message = "The flow log key must keep the default 30 day deletion window."
  }
}

run "endpoints_can_be_disabled" {
  command = plan

  variables {
    create_vpc_endpoints = false
  }

  assert {
    condition     = length(aws_vpc_endpoint.interface) == 0
    error_message = "No interface endpoints may be created when create_vpc_endpoints is false."
  }

  assert {
    condition     = length(aws_vpc_endpoint.s3) == 0
    error_message = "No gateway endpoints may be created when create_vpc_endpoints is false."
  }
}

run "rejects_single_az" {
  command = plan

  variables {
    azs              = ["eu-west-1a"]
    public_subnets   = ["10.20.0.0/20"]
    private_subnets  = ["10.20.48.0/20"]
    database_subnets = ["10.20.96.0/24"]
  }

  expect_failures = [var.azs]
}

run "rejects_mismatched_subnet_count" {
  command = plan

  variables {
    public_subnets = ["10.20.0.0/20"]
  }

  expect_failures = [var.public_subnets]
}

run "rejects_invalid_cidr" {
  command = plan

  variables {
    vpc_cidr = "10.20.0.0/33"
  }

  expect_failures = [var.vpc_cidr]
}
