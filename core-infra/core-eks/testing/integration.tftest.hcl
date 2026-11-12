# ---------------------------------------------------------------------------
# Integration test: plans the cluster stack with a CIDR-restricted public
# endpoint, x2 instance types and a smaller node group, proving the module
# graph resolves for a non-default networking posture.
# ---------------------------------------------------------------------------
mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"pods.eks.amazonaws.com\"},\"Action\":[\"sts:AssumeRole\",\"sts:TagSession\"]}]}"
    }
  }
}

override_data {
  target = data.aws_partition.current
  values = { partition = "aws" }
}

override_data {
  target = data.aws_caller_identity.current
  values = { account_id = "123456789012" }
}

override_data {
  target = module.eks.data.aws_iam_session_context.current[0]
  values = { issuer_arn = "arn:aws:iam::123456789012:user/terraform" }
}

override_data {
  target = module.eks.data.aws_partition.current[0]
  values = { partition = "aws" }
}

override_data {
  target = module.eks.data.aws_caller_identity.current[0]
  values = {
    account_id = "123456789012"
    arn        = "arn:aws:iam::123456789012:user/terraform"
    user_id    = "AIDAEXAMPLEUSERID"
  }
}

override_data {
  target = data.terraform_remote_state.vpc
  values = {
    outputs = {
      vpc_id                            = "vpc-0123456789abcdef0"
      vpc_cidr                          = "10.20.0.0/16"
      private_subnet_ids                = ["subnet-0aaa", "subnet-0bbb", "subnet-0ccc"]
      database_client_security_group_id = "sg-0123456789abcdef0"
    }
  }
}

override_data {
  target = data.terraform_remote_state.secretsmanager
  values = {
    outputs = {
      kubernetes_kubeconfig_secret_arn = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:sonarkube-dev/kubernetes/kubeconfig-AbCdEf"
    }
  }
}

variables {
  project     = "sonarkube"
  environment = "dev"
  aws_region  = "eu-west-1"

  state_bucket_name = "sonarkube-dev-eu-west-1-tfstate"

  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = ["203.0.113.0/24"]

  node_instance_types = ["m6i.large", "m7i.large"]
  node_min_size       = 2
  node_desired_size   = 2
  node_max_size       = 4
}

run "cluster_plans_with_restricted_public_endpoint" {
  command = plan

  assert {
    condition     = module.eks.cluster_name == "sonarkube-dev-eks"
    error_message = "The cluster name must remain stable across networking changes."
  }

  assert {
    condition     = aws_kms_alias.eks_secrets.name == "alias/sonarkube-dev-eks-secrets"
    error_message = "The cluster secrets key alias must remain stable."
  }

  assert {
    condition     = length(local.access_entries) == 0
    error_message = "No access entries must be created when no role ARNs are supplied."
  }
}
