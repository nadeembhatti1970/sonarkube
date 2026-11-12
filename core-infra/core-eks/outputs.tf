output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint (private by default)."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate authority bundle for the cluster."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_version" {
  description = "Kubernetes version running on the control plane."
  value       = module.eks.cluster_version
}

output "cluster_security_group_id" {
  description = "Security group attached to the EKS control plane ENIs."
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group attached to the managed node group ENIs."
  value       = module.eks.node_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the cluster OIDC provider used for IRSA roles."
  value       = module.eks.oidc_provider_arn
}

output "cluster_kms_key_arn" {
  description = "ARN of the KMS key used for envelope encryption of Kubernetes secrets."
  value       = module.eks.kms_key_arn
}

output "cluster_kms_key_alias" {
  description = "Alias of the Kubernetes secrets encryption key."
  value       = aws_kms_alias.eks_secrets.name
}

output "node_group_ids" {
  description = "Map of managed node group names to autoscaling group names."
  value       = module.eks.eks_managed_node_groups_autoscaling_group_names
}

output "cluster_addons" {
  description = "Map of installed EKS add-ons and their versions."
  value       = module.eks.cluster_addons
}

output "kubeconfig_secret_arn" {
  description = "ARN of the Secrets Manager secret that holds the cluster kubeconfig."
  value       = data.terraform_remote_state.secretsmanager.outputs.kubernetes_kubeconfig_secret_arn
}

output "cluster_iam_role_arn" {
  description = "ARN of the IAM role assumed by the EKS control plane."
  value       = module.eks.cluster_iam_role_arn
}
