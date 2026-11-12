# ---------------------------------------------------------------------------
# Unit tests: cluster hardening, access model and add-on wiring.
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

  kubernetes_version = "1.34"

  cluster_admin_role_arns  = ["arn:aws:iam::123456789012:role/break-glass"]
  cluster_editor_role_arns = ["arn:aws:iam::123456789012:role/github-actions-deploy"]
}

run "cluster_is_private_by_default" {
  command = plan

  assert {
    condition     = module.eks.cluster_name == "sonarkube-dev-eks"
    error_message = "The cluster must follow the <project>-<environment>-eks naming convention."
  }

  assert {
    condition     = module.eks.cluster_version == "1.34"
    error_message = "The control plane must run the pinned Kubernetes version."
  }

  assert {
    condition     = length(local.access_entries) == 2
    error_message = "Access entries must be generated for each admin and editor role."
  }
}

run "cross_plane_logs_are_encrypted" {
  command = plan

  assert {
    condition     = aws_kms_key.logs.enable_key_rotation
    error_message = "The control plane log key must rotate."
  }

  assert {
    condition     = aws_kms_alias.eks_secrets.name == "alias/sonarkube-dev-eks-secrets"
    error_message = "The cluster secrets key must have a stable alias."
  }
}

run "ebs_csi_uses_pod_identity" {
  command = plan

  assert {
    condition     = aws_iam_role.ebs_csi.name == "sonarkube-dev-ebs-csi-driver"
    error_message = "The EBS CSI driver must have a dedicated IAM role."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.ebs_csi.policy_arn == "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    error_message = "The driver role must be limited to the AWS managed EBS CSI policy."
  }
}

run "kubeconfig_is_published" {
  command = plan

  assert {
    condition     = aws_secretsmanager_secret_version.kubernetes_kubeconfig.secret_id == "arn:aws:secretsmanager:eu-west-1:123456789012:secret:sonarkube-dev/kubernetes/kubeconfig-AbCdEf"
    error_message = "The kubeconfig must be written to the secret created by core-secretsmanager."
  }
}

run "public_endpoint_is_opt_in" {
  command = plan

  variables {
    cluster_endpoint_public_access       = true
    cluster_endpoint_public_access_cidrs = ["203.0.113.0/24"]
  }

  assert {
    condition     = local.access_entries["cluster-admin-0"].policy_associations.admin.policy_arn == "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    error_message = "Admin roles must receive the cluster admin access policy."
  }
}

run "rejects_single_node_group_size" {
  command = plan

  variables {
    node_min_size = 1
  }

  expect_failures = [var.node_min_size]
}

run "rejects_invalid_role_arn" {
  command = plan

  variables {
    cluster_admin_role_arns = ["not-an-arn"]
  }

  expect_failures = [var.cluster_admin_role_arns]
}
