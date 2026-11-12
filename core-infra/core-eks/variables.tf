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

variable "kubernetes_version" {
  description = "EKS control plane version."
  type        = string
  default     = "1.34"

  validation {
    condition     = can(regex("^1\\.[0-9]{2}$", var.kubernetes_version))
    error_message = "kubernetes_version must be a supported EKS minor version, e.g. 1.34."
  }
}

variable "cluster_endpoint_public_access" {
  description = "Expose the Kubernetes API endpoint publicly. Disabled by default: CI runners must reach the cluster from inside the VPC."
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "Source CIDRs allowed to reach the public API endpoint when public access is enabled."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.cluster_endpoint_public_access_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Every entry in cluster_endpoint_public_access_cidrs must be a valid IPv4 CIDR."
  }
}

variable "cluster_log_retention_in_days" {
  description = "Retention period for the EKS control plane log group."
  type        = number
  default     = 365

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.cluster_log_retention_in_days)
    error_message = "cluster_log_retention_in_days must be a retention value supported by CloudWatch Logs."
  }
}

variable "cluster_kms_deletion_window_in_days" {
  description = "Waiting period before the EKS log key and cluster secrets key are destroyed after scheduling deletion."
  type        = number
  default     = 30

  validation {
    condition     = var.cluster_kms_deletion_window_in_days >= 7 && var.cluster_kms_deletion_window_in_days <= 30
    error_message = "cluster_kms_deletion_window_in_days must be between 7 and 30."
  }
}

variable "node_instance_types" {
  description = "Instance types for the SonarQube managed node group."
  type        = list(string)
  default     = ["m6i.large"]

  validation {
    condition     = length(var.node_instance_types) > 0
    error_message = "node_instance_types must contain at least one instance type."
  }
}

variable "node_capacity_type" {
  description = "Capacity type for the managed node group (ON_DEMAND or SPOT)."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 3

  validation {
    condition     = var.node_min_size >= 2
    error_message = "node_min_size must be at least 2 so that nodes can be spread across AZs."
  }
}

variable "node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 3

  validation {
    condition     = var.node_desired_size >= 2
    error_message = "node_desired_size must be at least 2."
  }
}

variable "node_max_size" {
  description = "Maximum number of worker nodes for the cluster autoscaler."
  type        = number
  default     = 6

  validation {
    condition     = var.node_max_size >= 3
    error_message = "node_max_size must be at least 3."
  }
}

variable "node_disk_size" {
  description = "Root EBS volume size in GiB for each worker node."
  type        = number
  default     = 100

  validation {
    condition     = var.node_disk_size >= 50
    error_message = "node_disk_size must be at least 50 GiB to host container images and logs."
  }
}

variable "cluster_admin_role_arns" {
  description = "IAM role ARNs granted AmazonEKSClusterAdminPolicy through EKS access entries."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for arn in var.cluster_admin_role_arns : can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/.+$", arn))])
    error_message = "Every entry in cluster_admin_role_arns must be a valid IAM role ARN."
  }
}

variable "cluster_editor_role_arns" {
  description = "IAM role ARNs granted AmazonEKSEditPolicy through EKS access entries (e.g. CI/CD deploy roles)."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for arn in var.cluster_editor_role_arns : can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/.+$", arn))])
    error_message = "Every entry in cluster_editor_role_arns must be a valid IAM role ARN."
  }
}

variable "kubeconfig_secret_version" {
  description = "Bump to republish the kubeconfig secret. The content is written write-only, so it is never stored in Terraform state."
  type        = number
  default     = 1

  validation {
    condition     = var.kubeconfig_secret_version >= 1
    error_message = "kubeconfig_secret_version must be at least 1."
  }
}

variable "tags" {
  description = "Additional tags merged into the default tag set applied to every resource."
  type        = map(string)
  default     = {}
}
