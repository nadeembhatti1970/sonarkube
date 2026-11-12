output "namespace" {
  description = "Kubernetes namespace that hosts SonarQube."
  value       = kubernetes_namespace_v1.sonarqube.metadata[0].name
}

output "release_name" {
  description = "Name of the Helm release."
  value       = helm_release.sonarqube.name
}

output "release_version" {
  description = "Revision of the deployed Helm release."
  value       = helm_release.sonarqube.metadata.revision
}

output "chart_version" {
  description = "Pinned SonarSource chart version that was deployed."
  value       = helm_release.sonarqube.version
}

output "service_name" {
  description = "In-cluster Kubernetes Service that fronts SonarQube. The chart names it <release>-<chart>, so the default is sonarqube-sonarqube."
  value       = "${helm_release.sonarqube.name}-sonarqube"
}

output "ingress_host" {
  description = "Hostname published in the Ingress rule (null when ingress is disabled)."
  value       = var.ingress_enabled ? var.ingress_host : null
}

output "database_secret_name" {
  description = "Kubernetes secret that holds the JDBC credentials."
  value       = local.db_secret_name
}

output "admin_secret_name" {
  description = "Kubernetes secret that holds the admin password, passcode and encryption key."
  value       = local.admin_secret_name
}

output "storage_class_name" {
  description = "StorageClass used for the SonarQube data volume."
  value       = kubernetes_storage_class_v1.ebs_gp3.metadata[0].name
}

output "database_endpoint" {
  description = "Private RDS endpoint SonarQube connects to."
  value       = "${data.terraform_remote_state.rds.outputs.db_instance_address}:${data.terraform_remote_state.rds.outputs.db_instance_port}"
}

output "status" {
  description = "Status of the Helm release as reported by the Helm provider."
  value       = helm_release.sonarqube.status
}
