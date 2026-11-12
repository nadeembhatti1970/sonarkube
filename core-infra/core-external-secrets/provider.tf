provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# ---------------------------------------------------------------------------
# Kubernetes authentication for Helm.
#
# The cluster endpoint is private, so this module runs from inside the VPC.
# Tokens are minted per request by `aws eks get-token`.
# ---------------------------------------------------------------------------
provider "helm" {
  kubernetes = {
    host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        data.terraform_remote_state.eks.outputs.cluster_name,
        "--region",
        var.aws_region,
      ]
    }
  }
}

locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      Component   = "external-secrets"
      ManagedBy   = "terraform"
      Owner       = "platform-engineering"
      Repository  = "sonarkube"
      DataClass   = "internal"
    },
    var.tags
  )
}
