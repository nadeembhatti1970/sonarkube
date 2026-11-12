provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      Component   = "secrets"
      ManagedBy   = "terraform"
      Owner       = "platform-engineering"
      Repository  = "sonarkube"
      DataClass   = "confidential"
    },
    var.tags
  )

  # Names follow a predictable hierarchy so that External Secrets Operator,
  # CI jobs and humans can find a credential without reading Terraform state.
  secret_names = {
    rds_master                       = "${local.name_prefix}/rds/master"
    sonarqube_database               = "${local.name_prefix}/sonarqube/database"
    sonarqube_admin_password         = "${local.name_prefix}/sonarqube/admin-password"
    sonarqube_monitoring_passcode    = "${local.name_prefix}/sonarqube/monitoring-passcode"
    sonarqube_server_secret_key      = "${local.name_prefix}/sonarqube/server-secret-key"
    sonarqube_admin_current_password = "${local.name_prefix}/sonarqube/admin-current-password"
    kubernetes_kubeconfig            = "${local.name_prefix}/kubernetes/kubeconfig"
  }

  # Characters that are safe in JDBC URLs, psql connection strings and shell
  # quoting are used for generated passwords; workspace-breaking characters
  # (quotes, backslashes, @, :, /) are excluded on purpose.
  password_special_characters = "!#%*-_=+"
}
