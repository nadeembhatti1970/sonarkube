# ---------------------------------------------------------------------------
# Dev environment inputs for core-rds.
#
#   terraform init -backend-config=dev.tfbackend
#   terraform plan -var-file=dev.tfvars
#   terraform apply -var-file=dev.tfvars
# ---------------------------------------------------------------------------

project     = "sonarkube"
environment = "dev"
aws_region  = "eu-west-1"

state_bucket_name = "sonarkube-dev-eu-west-1-tfstate"
state_key_prefix  = "environments"

engine_version = "17.6"
instance_class = "db.m6g.large"

db_username = "sonar_admin"
db_name     = "sonarqube"
db_port     = 5432

db_password_length = 32
# Bump to rotate the master password. The new value is ephemeral and only
# written through write-only arguments; External Secrets Operator refreshes the
# cluster within its interval, then restart the SonarQube pod.
db_password_revision = 1

allocated_storage     = 100
max_allocated_storage = 500
storage_iops          = 3000
storage_throughput    = 250

multi_az              = true
deletion_protection   = true
skip_final_snapshot   = false
backup_retention_days = 14
backup_window         = "02:00-03:00"
maintenance_window    = "sun:04:00-sun:05:00"

monitoring_interval                 = 60
performance_insights_retention_days = 7
force_ssl                           = true
log_retention_in_days               = 365
kms_deletion_window_in_days         = 30

ca_cert_identifier = "rds-ca-rsa2048-g1"

# Set to a real on-call address to receive alarm and RDS event notifications.
alarm_email = null

cpu_alarm_threshold_percent           = 80
free_storage_alarm_threshold_bytes    = 21474836480
freeable_memory_alarm_threshold_bytes = 536870912
max_connections_alarm_threshold       = 180

tags = {
  Owner      = "platform-engineering"
  CostCenter = "engineering-platform"
  DataClass  = "confidential"
}
