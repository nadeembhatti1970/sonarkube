variable "project" {
  description = "Short project identifier used to build resource names and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project))
    error_message = "project must be 3-21 characters, lowercase alphanumeric or hyphens, and start with a letter."
  }
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region that hosts the Secrets Manager secrets."
  type        = string
  default     = "eu-west-1"

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS region name, e.g. eu-west-1."
  }
}

variable "state_bucket_name" {
  description = "S3 bucket that holds the Terraform state for every root module in this environment."
  type        = string
}

variable "state_key_prefix" {
  description = "First path segment of the Terraform state keys, e.g. environments."
  type        = string
  default     = "environments"
}

variable "kms_deletion_window_in_days" {
  description = "Waiting period before the secrets KMS key is destroyed after scheduling deletion."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window_in_days >= 7 && var.kms_deletion_window_in_days <= 30
    error_message = "kms_deletion_window_in_days must be between 7 and 30."
  }
}

variable "secret_recovery_window_in_days" {
  description = "Recovery window for deleted secrets (0 disables recovery and is not recommended)."
  type        = number
  default     = 30

  validation {
    condition     = var.secret_recovery_window_in_days == 0 || (var.secret_recovery_window_in_days >= 7 && var.secret_recovery_window_in_days <= 30)
    error_message = "secret_recovery_window_in_days must be 0 or between 7 and 30."
  }
}

variable "sonarqube_admin_password_length" {
  description = "Length of the generated SonarQube local administrator password."
  type        = number
  default     = 32

  validation {
    condition     = var.sonarqube_admin_password_length >= 16 && var.sonarqube_admin_password_length <= 128
    error_message = "sonarqube_admin_password_length must be between 16 and 128."
  }
}

variable "sonarqube_current_admin_password" {
  description = "Administrator password currently in use, consumed by the chart's setAdminPassword hook. Defaults to the SonarQube bootstrap password and is supplied via TF_VAR_ on rotation."
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "sonarqube_credentials_version" {
  description = "Bump to rotate the SonarQube admin password, monitoring passcode and server encryption key. Write-only values are only rewritten when this number changes."
  type        = number
  default     = 1

  validation {
    condition     = var.sonarqube_credentials_version >= 1
    error_message = "sonarqube_credentials_version must be at least 1."
  }
}

variable "enable_rds_master_rotation" {
  description = "Enable automatic rotation of the RDS master secret. Requires a VPC-attached rotation Lambda (see README)."
  type        = bool
  default     = false
}

variable "rds_master_rotation_lambda_arn" {
  description = "ARN of the rotation Lambda invoked by Secrets Manager when rotation is enabled."
  type        = string
  default     = null

  validation {
    condition     = var.rds_master_rotation_lambda_arn == null || can(regex("^arn:aws[a-z-]*:lambda:[a-z0-9-]+:[0-9]{12}:function:.+$", var.rds_master_rotation_lambda_arn))
    error_message = "rds_master_rotation_lambda_arn must be a valid Lambda function ARN or null."
  }
}

variable "rds_master_rotation_days" {
  description = "Rotation interval, in days, for the RDS master secret."
  type        = number
  default     = 30

  validation {
    condition     = var.rds_master_rotation_days >= 1 && var.rds_master_rotation_days <= 365
    error_message = "rds_master_rotation_days must be between 1 and 365."
  }
}

variable "tags" {
  description = "Additional tags merged into the default tag set applied to every resource."
  type        = map(string)
  default     = {}
}
