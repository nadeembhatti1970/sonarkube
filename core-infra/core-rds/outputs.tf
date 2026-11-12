output "db_instance_id" {
  description = "Identifier of the SonarQube PostgreSQL instance."
  value       = aws_db_instance.sonarqube.id
}

output "db_instance_arn" {
  description = "ARN of the SonarQube PostgreSQL instance."
  value       = aws_db_instance.sonarqube.arn
}

output "db_instance_address" {
  description = "DNS name of the database endpoint (private, resolvable only inside the VPC)."
  value       = aws_db_instance.sonarqube.address
}

output "db_instance_port" {
  description = "TCP port the database listens on."
  value       = var.db_port
}

output "db_name" {
  description = "Initial database name used by SonarQube."
  value       = var.db_name
}

output "db_username" {
  description = "Master username used by SonarQube. The password lives only in Secrets Manager."
  value       = var.db_username
}

output "db_security_group_id" {
  description = "Security group guarding the database. Only the database-clients group may connect."
  value       = aws_security_group.rds.id
}

output "parameter_group_name" {
  description = "Name of the SonarQube tuned parameter group."
  value       = aws_db_parameter_group.sonarqube.name
}

output "kms_key_arn" {
  description = "ARN of the key that encrypts the database volume and snapshots."
  value       = aws_kms_key.rds.arn
}

output "logs_kms_key_arn" {
  description = "ARN of the key that encrypts exported PostgreSQL logs."
  value       = aws_kms_key.logs.arn
}

output "database_secret_arn" {
  description = "ARN of the JDBC JSON secret consumed by External Secrets Operator deployments."
  value       = data.terraform_remote_state.secretsmanager.outputs.sonarqube_database_secret_arn
}

output "jdbc_url" {
  description = "JDBC URL SonarQube should use to reach the database (no credentials embedded)."
  value       = local.jdbc_url
}

output "sslmode" {
  description = "TLS mode advertised to the JDBC driver."
  value       = local.jdbc_sslmode
}

output "alarm_topic_arn" {
  description = "ARN of the SNS topic that receives database alarms and RDS events."
  value       = aws_sns_topic.database_alarms.arn
}
