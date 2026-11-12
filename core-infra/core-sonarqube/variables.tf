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
  description = "AWS region that hosts the EKS cluster."
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
  description = "Kubernetes namespace that hosts SonarQube."
  type        = string
  default     = "sonarqube"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace)) && length(var.namespace) <= 63
    error_message = "namespace must be a valid RFC 1123 label (lowercase alphanumeric and hyphens, max 63 characters)."
  }
}

variable "chart_version" {
  description = "Pinned version of the official SonarSource sonarqube Helm chart."
  type        = string
  default     = "2026.5.1004"

  validation {
    condition     = can(regex("^[0-9]{4}\\.[0-9]+\\.[0-9]+$", var.chart_version))
    error_message = "chart_version must be an exact chart version, e.g. 2026.5.1004."
  }
}

variable "helm_timeout_seconds" {
  description = "Time, in seconds, Terraform waits for the Helm release to become ready."
  type        = number
  default     = 900

  validation {
    condition     = var.helm_timeout_seconds >= 300
    error_message = "helm_timeout_seconds must be at least 300 to allow the SonarQube database migration to finish."
  }
}

variable "storage_class_name" {
  description = "StorageClass created for SonarQube's persistent volume (EBS gp3)."
  type        = string
  default     = "ebs-gp3"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.storage_class_name))
    error_message = "storage_class_name must be a valid Kubernetes object name."
  }
}

variable "set_default_storage_class" {
  description = "Mark the created gp3 StorageClass as the cluster default."
  type        = bool
  default     = true
}

variable "persistence_size" {
  description = "Size of the SonarQube data volume."
  type        = string
  default     = "20Gi"

  validation {
    condition     = can(regex("^[0-9]+(Gi|Ti)$", var.persistence_size))
    error_message = "persistence_size must be a Kubernetes quantity in Gi or Ti, e.g. 20Gi."
  }
}

variable "cpu_request" {
  description = "CPU request for the SonarQube container."
  type        = string
  default     = "1"
}

variable "cpu_limit" {
  description = "CPU limit for the SonarQube container."
  type        = string
  default     = "2"
}

variable "memory_request" {
  description = "Memory request for the SonarQube container."
  type        = string
  default     = "4Gi"
}

variable "memory_limit" {
  description = "Memory limit for the SonarQube container."
  type        = string
  default     = "8Gi"
}

variable "service_type" {
  description = "Kubernetes Service type for SonarQube. ClusterIP keeps the app internal and is fronted by an Ingress."
  type        = string
  default     = "ClusterIP"

  validation {
    condition     = contains(["ClusterIP", "LoadBalancer"], var.service_type)
    error_message = "service_type must be ClusterIP or LoadBalancer."
  }
}

variable "ingress_enabled" {
  description = "Create an Ingress for SonarQube. Requires an installed ingress controller (ALB or nginx)."
  type        = bool
  default     = false
}

variable "ingress_class_name" {
  description = "Ingress class used when ingress_enabled is true (alb, nginx, ...)."
  type        = string
  default     = "alb"
}

variable "ingress_host" {
  description = "DNS name published in the Ingress rule."
  type        = string
  default     = "sonarqube.dev.sonarkube.internal"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9.]*[a-z0-9])?$", var.ingress_host))
    error_message = "ingress_host must be a valid DNS name."
  }
}

variable "ingress_annotations" {
  description = "Additional annotations merged into the Ingress object (e.g. ALB listen-ports, ACM certificate ARN)."
  type        = map(string)
  default     = {}
}

variable "ingress_tls_secret_name" {
  description = "Optional TLS secret name for the Ingress. ALB users usually prefer the ACM certificate annotation instead."
  type        = string
  default     = null
}

variable "external_secrets_store_name" {
  description = "ClusterSecretStore created by core-external-secrets and referenced by the SonarQube ExternalSecrets."
  type        = string
  default     = "aws-secretsmanager"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.external_secrets_store_name))
    error_message = "external_secrets_store_name must be a valid Kubernetes object name."
  }
}

variable "external_secrets_refresh_interval" {
  description = "How often External Secrets Operator re-reads the SonarQube secrets (for example 1m, 15m, 1h)."
  type        = string
  default     = "1h"

  validation {
    condition     = can(regex("^[0-9]+(s|m|h)$", var.external_secrets_refresh_interval))
    error_message = "external_secrets_refresh_interval must be a duration such as 30s, 15m or 1h."
  }
}

variable "sonar_properties" {
  description = "Additional sonar.properties entries passed to the chart (for example sonar.forceAuthentication)."
  type        = map(string)
  default     = {}
}

variable "pod_labels" {
  description = "Extra labels applied to the SonarQube pods."
  type        = map(string)
  default = {
    "app.kubernetes.io/part-of" = "code-quality-platform"
  }
}

variable "tags" {
  description = "Additional tags merged into the default tag set applied to every AWS resource."
  type        = map(string)
  default     = {}
}
