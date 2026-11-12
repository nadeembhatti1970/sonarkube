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
      Component   = "network"
      ManagedBy   = "terraform"
      Owner       = "platform-engineering"
      Repository  = "sonarkube"
      Compliance  = "cis-aws-1.5"
    },
    var.tags
  )
}
