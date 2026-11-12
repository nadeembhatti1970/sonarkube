# ---------------------------------------------------------------------------
# EKS cluster, managed node group and add-ons.
#
# Hardening decisions:
#   * API endpoint is private only by default; public access must be enabled
#     explicitly and is CIDR restricted.
#   * Secrets are envelope encrypted with a cluster-dedicated KMS key created
#     and granted by the module (AWS best practice for EKS).
#   * Access is managed exclusively through EKS access entries (API auth
#     mode); no aws-auth ConfigMap mutation, no static cluster tokens.
#   * Nodes run in private subnets, use IMDSv2-only, encrypted gp3 volumes and
#     carry the shared database-clients security group so RDS can allow them.
# ---------------------------------------------------------------------------
locals {
  access_entries = merge(
    {
      for index, role_arn in var.cluster_admin_role_arns : "cluster-admin-${index}" => {
        principal_arn     = role_arn
        kubernetes_groups = []
        tags              = { ManagedBy = "terraform", AccessLevel = "cluster-admin" }
        policy_associations = {
          admin = {
            policy_arn = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }
    },
    {
      for index, role_arn in var.cluster_editor_role_arns : "cluster-editor-${index}" => {
        principal_arn     = role_arn
        kubernetes_groups = []
        tags              = { ManagedBy = "terraform", AccessLevel = "cluster-editor" }
        policy_associations = {
          edit = {
            policy_arn = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }
    },
  )
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.29.0"

  name               = "${local.name_prefix}-eks"
  kubernetes_version = var.kubernetes_version

  vpc_id                   = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids               = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  control_plane_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids

  endpoint_private_access      = true
  endpoint_public_access       = var.cluster_endpoint_public_access
  endpoint_public_access_cidrs = var.cluster_endpoint_public_access ? var.cluster_endpoint_public_access_cidrs : null

  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true
  access_entries                           = local.access_entries

  # Cluster secrets envelope encryption with a dedicated customer managed key.
  create_kms_key                  = true
  enable_kms_key_rotation         = true
  kms_key_deletion_window_in_days = var.cluster_kms_deletion_window_in_days
  encryption_config = {
    resources = ["secrets"]
  }

  # Control plane logging for audit, authentication and operational triage.
  enabled_log_types                      = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  create_cloudwatch_log_group            = true
  cloudwatch_log_group_retention_in_days = var.cluster_log_retention_in_days
  cloudwatch_log_group_kms_key_id        = aws_kms_key.logs.arn

  enable_irsa = true

  addons = {
    vpc-cni = {
      before_compute = true
      most_recent    = true
    }
    eks-pod-identity-agent = {
      before_compute = true
      most_recent    = true
    }
    kube-proxy = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      pod_identity_association = [
        {
          role_arn        = aws_iam_role.ebs_csi.arn
          service_account = "ebs-csi-driver"
        }
      ]
    }
  }

  eks_managed_node_groups = {
    sonarqube = {
      name           = "${local.name_prefix}-sonarqube"
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type

      min_size     = var.node_min_size
      desired_size = var.node_desired_size
      max_size     = var.node_max_size

      # The shared database-clients group is what the RDS security group
      # references; attaching it here is the only way traffic can reach 5432.
      vpc_security_group_ids = [data.terraform_remote_state.vpc.outputs.database_client_security_group_id]

      labels = {
        role        = "sonarqube"
        environment = var.environment
      }

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
        http_protocol_ipv6          = "disabled"
      }

      block_device_mappings = {
        root = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = var.node_disk_size
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      # Explicit role name keeps the generated IAM role under the 38 character
      # name_prefix limit imposed by IAM.
      iam_role_name            = "${local.name_prefix}-eks-node"
      iam_role_use_name_prefix = false

      iam_role_additional_policies = {
        ssm = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      tags = {
        "k8s.io/cluster-autoscaler/enabled"                  = "true"
        "k8s.io/cluster-autoscaler/${local.name_prefix}-eks" = "owned"
      }
    }
  }

  node_security_group_enable_recommended_rules = true

  tags = local.common_tags

  cluster_tags = {
    Name = "${local.name_prefix}-eks"
  }
}

# Human-friendly alias for the cluster secrets encryption key. The module
# requires static alias strings, so the alias is created here instead.
resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${local.name_prefix}-eks-secrets"
  target_key_id = module.eks.kms_key_id
}
