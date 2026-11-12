# ---------------------------------------------------------------------------
# Kubernetes authentication.
#
# Both providers authenticate with short-lived tokens minted by
# `aws eks get-token`; nothing long-lived is written to disk or to state.
# The cluster endpoint is private, so this module must run from inside the VPC.
#
# There is no AWS provider: secrets are never read by Terraform. External
# Secrets Operator syncs them into the cluster at runtime.
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

provider "kubernetes" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)

  exec {
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
