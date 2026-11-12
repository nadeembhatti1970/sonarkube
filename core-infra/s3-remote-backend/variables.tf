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
  description = "AWS region that hosts the Terraform state bucket and every workload resource."
  type        = string
  default     = "eu-west-1"

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS region name, e.g. eu-west-1."
  }
}

variable "state_bucket_name" {
  description = "Globally unique name of the S3 bucket that stores Terraform state for all root modules."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a valid, globally unique S3 bucket name (3-63 characters)."
  }
}

variable "state_access_logs_bucket_name" {
  description = "Name of the S3 bucket that receives server access logs for the state bucket."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_access_logs_bucket_name))
    error_message = "state_access_logs_bucket_name must be a valid, globally unique S3 bucket name (3-63 characters)."
  }
}

variable "kms_deletion_window_in_days" {
  description = "Waiting period, in days, before the state bucket KMS key is destroyed after scheduling deletion."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window_in_days >= 7 && var.kms_deletion_window_in_days <= 30
    error_message = "kms_deletion_window_in_days must be between 7 and 30."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Number of days after which non-current state object versions are permanently deleted."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_expiration_days >= 30
    error_message = "noncurrent_version_expiration_days must be at least 30 to retain a usable recovery window."
  }
}

variable "tags" {
  description = "Additional tags merged into the default tag set applied to every resource."
  type        = map(string)
  default     = {}
}
