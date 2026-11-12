output "namespace" {
  description = "Namespace that runs the External Secrets Operator."
  value       = helm_release.external_secrets.namespace
}

output "release_name" {
  description = "Name of the External Secrets Operator Helm release."
  value       = helm_release.external_secrets.name
}

output "chart_version" {
  description = "Pinned external-secrets chart version."
  value       = helm_release.external_secrets.version
}

output "service_account_name" {
  description = "Service account bound to the controller IAM role."
  value       = var.service_account_name
}

output "iam_role_arn" {
  description = "ARN of the IAM role used by the controller (Pod Identity)."
  value       = aws_iam_role.external_secrets.arn
}

output "secret_store_name" {
  description = "Name of the ClusterSecretStore that application modules reference."
  value       = var.secret_store_name
}
