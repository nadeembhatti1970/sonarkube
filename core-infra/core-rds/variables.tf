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
  description = "AWS region that hosts the RDS instance."
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

variable "db_username" {
  description = "Master username for the SonarQube PostgreSQL instance."
  type        = string
  default     = "sonar_admin"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{2,62}$", var.db_username))
    error_message = "db_username must start with a lowercase letter and contain 3-63 lowercase alphanumeric or underscore characters."
  }
}

variable "db_name" {
  description = "Initial database created for SonarQube."
  type        = string
  default     = "sonarqube"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{2,62}$", var.db_name))
    error_message = "db_name must start with a lowercase letter and contain 3-63 lowercase alphanumeric or underscore characters."
  }
}

variable "db_port" {
  description = "TCP port PostgreSQL listens on inside the VPC."
  type        = number
  default     = 5432

  validation {
    condition     = var.db_port >= 1150 && var.db_port <= 65535
    error_message = "db_port must be between 1150 and 65535."
  }
}

variable "db_password_length" {
  description = "Length of the ephemeral master password generated on each credential rotation."
  type        = number
  default     = 32

  validation {
    condition     = var.db_password_length >= 24 && var.db_password_length <= 128
    error_message = "db_password_length must be between 24 and 128."
  }
}

variable "db_password_revision" {
  description = "Bump to rotate the master password. The new password is ephemeral and is only written to RDS/Secrets Manager through write-only arguments."
  type        = number
  default     = 1

  validation {
    condition     = var.db_password_revision >= 1
    error_message = "db_password_revision must be at least 1."
  }
}

variable "engine_version" {
  description = "PostgreSQL engine version for the SonarQube database."
  type        = string
  default     = "17.6"

  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?$", var.engine_version))
    error_message = "engine_version must be a major or major.minor PostgreSQL version, e.g. 17.6."
  }
}

variable "instance_class" {
  description = "RDS instance class. SonarQube benefits from memory and burst IOPS, so m-class Graviton is the default."
  type        = string
  default     = "db.m6g.large"
}

variable "allocated_storage" {
  description = "Initial gp3 storage allocation in GiB."
  type        = number
  default     = 100

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "allocated_storage must be at least 20 GiB."
  }
}

variable "max_allocated_storage" {
  description = "Upper bound for RDS storage autoscaling in GiB (0 disables autoscaling)."
  type        = number
  default     = 500

  validation {
    condition     = var.max_allocated_storage == 0 || var.max_allocated_storage >= 100
    error_message = "max_allocated_storage must be 0 or at least 100 GiB."
  }
}

variable "storage_iops" {
  description = "Provisioned IOPS for the gp3 volume."
  type        = number
  default     = 3000

  validation {
    condition     = var.storage_iops >= 3000 && var.storage_iops <= 64000
    error_message = "storage_iops for gp3 must be between 3000 and 64000."
  }
}

variable "storage_throughput" {
  description = "Provisioned throughput in MiB/s for the gp3 volume."
  type        = number
  default     = 250

  validation {
    condition     = var.storage_throughput >= 125 && var.storage_throughput <= 4000
    error_message = "storage_throughput for gp3 must be between 125 and 4000 MiB/s."
  }
}

variable "multi_az" {
  description = "Deploy a synchronous standby in a second AZ. Required for production grade resilience."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Block deletion of the database via the API. Must be disabled deliberately during teardown."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot on destroy. Only acceptable for disposable environments."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Automated backup retention period in days (0 disables backups)."
  type        = number
  default     = 14

  validation {
    condition     = var.backup_retention_days == 0 || (var.backup_retention_days >= 1 && var.backup_retention_days <= 35)
    error_message = "backup_retention_days must be 0 or between 1 and 35."
  }
}

variable "backup_window" {
  description = "UTC window for automated backups (must not overlap the maintenance window)."
  type        = string
  default     = "02:00-03:00"

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]-([01][0-9]|2[0-3]):[0-5][0-9]$", var.backup_window))
    error_message = "backup_window must use the hh24:mi-hh24:mi UTC format."
  }
}

variable "maintenance_window" {
  description = "UTC window for RDS maintenance (must not overlap the backup window)."
  type        = string
  default     = "sun:04:00-sun:05:00"

  validation {
    condition     = can(regex("^(mon|tue|wed|thu|fri|sat|sun):([01][0-9]|2[0-3]):[0-5][0-9]-(mon|tue|wed|thu|fri|sat|sun):([01][0-9]|2[0-3]):[0-5][0-9]$", var.maintenance_window))
    error_message = "maintenance_window must use the ddd:hh24:mi-ddd:hh24:mi format."
  }
}

variable "monitoring_interval" {
  description = "Enhanced Monitoring interval in seconds (0, 1, 5, 10, 15, 30 or 60)."
  type        = number
  default     = 60

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "monitoring_interval must be one of: 0, 1, 5, 10, 15, 30, 60."
  }
}

variable "performance_insights_retention_days" {
  description = "Performance Insights retention period in days (7 is the free tier, 465 the long-term tier)."
  type        = number
  default     = 7

  validation {
    condition     = contains([7, 465, 731, 1093, 1461, 1825, 2192, 2557, 2922, 3288, 3653], var.performance_insights_retention_days)
    error_message = "performance_insights_retention_days must be a value supported by RDS Performance Insights."
  }
}

variable "ca_cert_identifier" {
  description = "RDS certificate authority used for TLS connections from SonarQube."
  type        = string
  default     = "rds-ca-rsa2048-g1"
}

variable "force_ssl" {
  description = "Set rds.force_ssl=1 on the parameter group and advertise sslmode=require in the JDBC URL."
  type        = bool
  default     = true
}

variable "log_retention_in_days" {
  description = "Retention for the PostgreSQL and upgrade log groups exported to CloudWatch Logs."
  type        = number
  default     = 365

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_in_days)
    error_message = "log_retention_in_days must be a retention value supported by CloudWatch Logs."
  }
}

variable "kms_deletion_window_in_days" {
  description = "Waiting period before the RDS storage and log KMS keys are destroyed after scheduling deletion."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window_in_days >= 7 && var.kms_deletion_window_in_days <= 30
    error_message = "kms_deletion_window_in_days must be between 7 and 30."
  }
}

variable "alarm_email" {
  description = "Optional email address subscribed to the database alarm topic."
  type        = string
  default     = null

  validation {
    condition     = var.alarm_email == null || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alarm_email))
    error_message = "alarm_email must be a valid email address or null."
  }
}

variable "cpu_alarm_threshold_percent" {
  description = "CPU utilisation percentage that triggers the sustained CPU alarm."
  type        = number
  default     = 80

  validation {
    condition     = var.cpu_alarm_threshold_percent > 0 && var.cpu_alarm_threshold_percent <= 100
    error_message = "cpu_alarm_threshold_percent must be greater than 0 and at most 100."
  }
}

variable "free_storage_alarm_threshold_bytes" {
  description = "Free storage threshold in bytes below which the storage alarm fires."
  type        = number
  default     = 21474836480
}

variable "freeable_memory_alarm_threshold_bytes" {
  description = "Freeable memory threshold in bytes below which the memory alarm fires."
  type        = number
  default     = 536870912
}

variable "max_connections_alarm_threshold" {
  description = "Database connection count above which the connection alarm fires."
  type        = number
  default     = 180
}

variable "tags" {
  description = "Additional tags merged into the default tag set applied to every resource."
  type        = map(string)
  default     = {}
}
