# ---------------------------------------------------------------------------
# Publish a ready-to-use kubeconfig to Secrets Manager.
#
# The kubeconfig has no embedded credentials: the user entry shells out to
# `aws eks get-token`, so every kubectl/helm call exchanges the caller's IAM
# identity for a short-lived STS token. Rotating or revoking access is an IAM
# and EKS access-entry concern, not a kubeconfig concern.
#
# It is still published with a write-only argument so no cluster metadata is
# persisted in Terraform state.
# ---------------------------------------------------------------------------
locals {
  kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = module.eks.cluster_name

    clusters = [
      {
        name = module.eks.cluster_name
        cluster = {
          server                       = module.eks.cluster_endpoint
          "certificate-authority-data" = module.eks.cluster_certificate_authority_data
        }
      }
    ]

    contexts = [
      {
        name = module.eks.cluster_name
        context = {
          cluster = module.eks.cluster_name
          user    = "aws"
        }
      }
    ]

    users = [
      {
        name = "aws"
        user = {
          exec = {
            apiVersion = "client.authentication.k8s.io/v1beta1"
            command    = "aws"
            args = [
              "eks",
              "get-token",
              "--cluster-name",
              module.eks.cluster_name,
              "--region",
              var.aws_region,
            ]
          }
        }
      }
    ]
  })
}

resource "aws_secretsmanager_secret_version" "kubernetes_kubeconfig" {
  secret_id                = data.terraform_remote_state.secretsmanager.outputs.kubernetes_kubeconfig_secret_arn
  secret_string_wo         = local.kubeconfig
  secret_string_wo_version = var.kubeconfig_secret_version

  depends_on = [module.eks]
}
