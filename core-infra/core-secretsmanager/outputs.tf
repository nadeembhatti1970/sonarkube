output "kms_key_arn" {
  description = "ARN of the customer managed key that encrypts every application secret."
  value       = aws_kms_key.secrets.arn
}

output "kms_key_alias" {
  description = "Alias of the key that encrypts application secrets."
  value       = aws_kms_alias.secrets.name
}

output "rds_master_secret_arn" {
  description = "ARN of the secret container for the RDS master credentials (version written by core-rds)."
  value       = aws_secretsmanager_secret.rds_master.arn
}

output "rds_master_secret_name" {
  description = "Name of the secret container for the RDS master credentials."
  value       = aws_secretsmanager_secret.rds_master.name
}

output "sonarqube_database_secret_arn" {
  description = "ARN of the JDBC JSON secret consumed by External Secrets Operator."
  value       = aws_secretsmanager_secret.sonarqube_database.arn
}

output "sonarqube_database_secret_name" {
  description = "Name of the JDBC JSON secret consumed by External Secrets Operator."
  value       = aws_secretsmanager_secret.sonarqube_database.name
}

output "sonarqube_admin_password_secret_arn" {
  description = "ARN of the secret holding the SonarQube administrator password."
  value       = aws_secretsmanager_secret.sonarqube_admin_password.arn
}

output "sonarqube_admin_password_secret_name" {
  description = "Name of the secret holding the SonarQube administrator password."
  value       = aws_secretsmanager_secret.sonarqube_admin_password.name
}

output "sonarqube_admin_current_password_secret_arn" {
  description = "ARN of the secret holding the previous (currently active) administrator password."
  value       = aws_secretsmanager_secret.sonarqube_admin_current_password.arn
}

output "sonarqube_admin_current_password_secret_name" {
  description = "Name of the secret holding the previous (currently active) administrator password."
  value       = aws_secretsmanager_secret.sonarqube_admin_current_password.name
}

output "sonarqube_monitoring_passcode_secret_arn" {
  description = "ARN of the secret holding the SonarQube monitoring passcode."
  value       = aws_secretsmanager_secret.sonarqube_monitoring_passcode.arn
}

output "sonarqube_monitoring_passcode_secret_name" {
  description = "Name of the secret holding the SonarQube monitoring passcode."
  value       = aws_secretsmanager_secret.sonarqube_monitoring_passcode.name
}

output "sonarqube_server_secret_key_secret_arn" {
  description = "ARN of the secret holding the SonarQube server-side encryption key (sonar-secret.txt)."
  value       = aws_secretsmanager_secret.sonarqube_server_secret_key.arn
}

output "sonarqube_server_secret_key_secret_name" {
  description = "Name of the secret holding the SonarQube server-side encryption key (sonar-secret.txt)."
  value       = aws_secretsmanager_secret.sonarqube_server_secret_key.name
}

output "kubernetes_kubeconfig_secret_arn" {
  description = "ARN of the secret that core-eks populates with the cluster kubeconfig."
  value       = aws_secretsmanager_secret.kubernetes_kubeconfig.arn
}

output "kubernetes_kubeconfig_secret_name" {
  description = "Name of the secret that core-eks populates with the cluster kubeconfig."
  value       = aws_secretsmanager_secret.kubernetes_kubeconfig.name
}

output "secret_arns" {
  description = "Map of logical secret name to Secrets Manager ARN, used to scope the External Secrets Operator IAM policy."
  value = {
    rds_master                       = aws_secretsmanager_secret.rds_master.arn
    sonarqube_database               = aws_secretsmanager_secret.sonarqube_database.arn
    sonarqube_admin_password         = aws_secretsmanager_secret.sonarqube_admin_password.arn
    sonarqube_admin_current_password = aws_secretsmanager_secret.sonarqube_admin_current_password.arn
    sonarqube_monitoring_passcode    = aws_secretsmanager_secret.sonarqube_monitoring_passcode.arn
    sonarqube_server_secret_key      = aws_secretsmanager_secret.sonarqube_server_secret_key.arn
    kubernetes_kubeconfig            = aws_secretsmanager_secret.kubernetes_kubeconfig.arn
  }
}
