provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  name_prefix = "${var.project}-${var.environment}"

  db_identifier = "${local.name_prefix}-sonarqube-pg"

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      Component   = "database"
      ManagedBy   = "terraform"
      Owner       = "platform-engineering"
      Repository  = "sonarkube"
      DataClass   = "confidential"
    },
    var.tags
  )
}
