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
  description = "AWS region that hosts the EKS cluster and Secrets Manager."
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

variable "namespace" {
  description = "Kubernetes namespace for the External Secrets Operator controller."
  type        = string
  default     = "external-secrets"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace)) && length(var.namespace) <= 63
    error_message = "namespace must be a valid RFC 1123 label."
  }
}

variable "service_account_name" {
  description = "Service account used by the controller and bound to the IAM role through EKS Pod Identity."
  type        = string
  default     = "external-secrets"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.service_account_name))
    error_message = "service_account_name must be a valid Kubernetes service account name."
  }
}

variable "chart_version" {
  description = "Pinned version of the external-secrets Helm chart."
  type        = string
  default     = "2.15.0"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.chart_version))
    error_message = "chart_version must be an exact chart version, e.g. 2.15.0."
  }
}

variable "replica_count" {
  description = "Controller replica count."
  type        = number
  default     = 1

  validation {
    condition     = var.replica_count >= 1
    error_message = "replica_count must be at least 1."
  }
}

variable "secret_store_name" {
  description = "Name of the cluster-wide ClusterSecretStore used by application modules."
  type        = string
  default     = "aws-secretsmanager"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.secret_store_name))
    error_message = "secret_store_name must be a valid Kubernetes object name."
  }
}

variable "helm_timeout_seconds" {
  description = "Time, in seconds, Terraform waits for each Helm release."
  type        = number
  default     = 600

  validation {
    condition     = var.helm_timeout_seconds >= 120
    error_message = "helm_timeout_seconds must be at least 120."
  }
}

variable "tags" {
  description = "Additional tags merged into the default tag set applied to every AWS resource."
  type        = map(string)
  default     = {}
}
