# core-eks

Private EKS cluster, one managed node group for SonarQube, and the add-ons that
make persistent volumes and pod identity work. Built on
`terraform-aws-modules/eks/aws` (21.29.0).

## Cluster configuration

| Setting | Value |
| :--- | :--- |
| Kubernetes version | `1.34` (input, validated as `1.xx`) |
| API endpoint | private by default; public access is opt-in with required CIDRs |
| Authentication | `API` mode, EKS access entries only (no `aws-auth` mutation) |
| Secrets encryption | dedicated CMK created and granted by the module |
| Control plane logs | api, audit, authenticator, controllerManager, scheduler -> KMS-encrypted CloudWatch, 365 days |
| Nodes | EKS managed, AL2023, private subnets, IMDSv2 required, encrypted gp3 root volume |
| Node IAM | SSM core policy for Session Manager access, plus the shared `database-clients` SG |

## Add-ons

| Add-on | Notes |
| :--- | :--- |
| `vpc-cni` | `before_compute = true` so pods can get IPs before nodes join |
| `eks-pod-identity-agent` | `before_compute = true` |
| `kube-proxy`, `coredns` | most recent compatible versions |
| `aws-ebs-csi-driver` | Pod Identity association to `sonarkube-<env>-ebs-csi-driver`; required by SonarQube's PVC |

No static AWS credentials or node-wide EBS permissions are granted: the CSI
driver assumes its role through the service account.

## Access model

```hcl
cluster_admin_role_arns  = ["arn:aws:iam::<account>:role/break-glass"]
cluster_editor_role_arns = ["arn:aws:iam::<account>:role/github-actions-deploy"]
```

These produce access entries with `AmazonEKSClusterAdminPolicy` or
`AmazonEKSEditPolicy` at cluster scope. The cluster creator is also granted
admin so the first apply is not locked out. Nothing is hardcoded.

## Kubeconfig

`kubeconfig-secret.tf` writes a kubeconfig into
`<project>-<env>/kubernetes/kubeconfig` (created by `core-secretsmanager`) using
a write-only argument, so the cluster metadata is not persisted in Terraform
state either. The user entry runs `aws eks get-token`, so the file is safe to
distribute to CI: authorisation is decided by IAM and EKS access entries at
request time.

```bash
aws secretsmanager get-secret-value \
  --secret-id sonarkube-dev/kubernetes/kubeconfig \
  --query SecretString --output text > ~/.kube/sonarkube-dev.yaml
kubectl --kubeconfig ~/.kube/sonarkube-dev.yaml get nodes
```

## Usage

```bash
terraform init -backend-config=dev.tfbackend
terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

## Key inputs

| Name | Description | Default |
| :--- | :--- | :--- |
| `kubernetes_version` | Control plane version | `1.34` |
| `cluster_endpoint_public_access` | Expose the API publicly | `false` |
| `cluster_endpoint_public_access_cidrs` | Allowed CIDRs when public | `[]` |
| `node_instance_types` | Worker instance types | `["m6i.large"]` |
| `node_min_size` / `node_desired_size` / `node_max_size` | Group sizing | `3` / `3` / `6` |
| `cluster_admin_role_arns` | Admin access entries | `[]` |
| `cluster_editor_role_arns` | Editor access entries (CI/CD) | `[]` |
| `cluster_log_retention_in_days` | Control plane log retention | `365` |

## Outputs

`cluster_name`, `cluster_arn`, `cluster_endpoint`,
`cluster_certificate_authority_data` (sensitive), `cluster_version`,
`cluster_security_group_id`, `node_security_group_id`, `oidc_provider_arn`,
`cluster_kms_key_arn`, `cluster_kms_key_alias`, `node_group_ids`,
`cluster_addons`, `kubeconfig_secret_arn`, `cluster_iam_role_arn`.

## Notes

* Node group IAM role names are set explicitly: the module's generated
  name prefix would exceed the 38 character IAM limit for this project name.
* Cluster autoscaler annotations are applied to the node group; the autoscaler
  itself is out of scope (install it as a platform add-on if you need scaling
  beyond the desired size).
* Because the endpoint is private, `core-sonarqube` must be applied from inside
  the VPC. Use SSM Session Manager (the node role already has the SSM policy) or
  a VPC-attached CI runner.

## Reference

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.73.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | 21.29.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_role.ebs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ebs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.eks_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_alias.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_secretsmanager_secret_version.kubernetes_kubeconfig](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.ebs_csi_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [terraform_remote_state.secretsmanager](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |
| [terraform_remote_state.vpc](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region that hosts the EKS cluster. | `string` | `"eu-west-1"` | no |
| <a name="input_cluster_admin_role_arns"></a> [cluster\_admin\_role\_arns](#input\_cluster\_admin\_role\_arns) | IAM role ARNs granted AmazonEKSClusterAdminPolicy through EKS access entries. | `list(string)` | `[]` | no |
| <a name="input_cluster_editor_role_arns"></a> [cluster\_editor\_role\_arns](#input\_cluster\_editor\_role\_arns) | IAM role ARNs granted AmazonEKSEditPolicy through EKS access entries (e.g. CI/CD deploy roles). | `list(string)` | `[]` | no |
| <a name="input_cluster_endpoint_public_access"></a> [cluster\_endpoint\_public\_access](#input\_cluster\_endpoint\_public\_access) | Expose the Kubernetes API endpoint publicly. Disabled by default: CI runners must reach the cluster from inside the VPC. | `bool` | `false` | no |
| <a name="input_cluster_endpoint_public_access_cidrs"></a> [cluster\_endpoint\_public\_access\_cidrs](#input\_cluster\_endpoint\_public\_access\_cidrs) | Source CIDRs allowed to reach the public API endpoint when public access is enabled. | `list(string)` | `[]` | no |
| <a name="input_cluster_kms_deletion_window_in_days"></a> [cluster\_kms\_deletion\_window\_in\_days](#input\_cluster\_kms\_deletion\_window\_in\_days) | Waiting period before the EKS log key and cluster secrets key are destroyed after scheduling deletion. | `number` | `30` | no |
| <a name="input_cluster_log_retention_in_days"></a> [cluster\_log\_retention\_in\_days](#input\_cluster\_log\_retention\_in\_days) | Retention period for the EKS control plane log group. | `number` | `365` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (dev, staging, prod). | `string` | n/a | yes |
| <a name="input_kubeconfig_secret_version"></a> [kubeconfig\_secret\_version](#input\_kubeconfig\_secret\_version) | Bump to republish the kubeconfig secret. The content is written write-only, so it is never stored in Terraform state. | `number` | `1` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | EKS control plane version. | `string` | `"1.34"` | no |
| <a name="input_node_capacity_type"></a> [node\_capacity\_type](#input\_node\_capacity\_type) | Capacity type for the managed node group (ON\_DEMAND or SPOT). | `string` | `"ON_DEMAND"` | no |
| <a name="input_node_desired_size"></a> [node\_desired\_size](#input\_node\_desired\_size) | Desired number of worker nodes. | `number` | `3` | no |
| <a name="input_node_disk_size"></a> [node\_disk\_size](#input\_node\_disk\_size) | Root EBS volume size in GiB for each worker node. | `number` | `100` | no |
| <a name="input_node_instance_types"></a> [node\_instance\_types](#input\_node\_instance\_types) | Instance types for the SonarQube managed node group. | `list(string)` | <pre>[<br/>  "m6i.large"<br/>]</pre> | no |
| <a name="input_node_max_size"></a> [node\_max\_size](#input\_node\_max\_size) | Maximum number of worker nodes for the cluster autoscaler. | `number` | `6` | no |
| <a name="input_node_min_size"></a> [node\_min\_size](#input\_node\_min\_size) | Minimum number of worker nodes. | `number` | `3` | no |
| <a name="input_project"></a> [project](#input\_project) | Short project identifier used to build resource names and tags. | `string` | n/a | yes |
| <a name="input_state_bucket_name"></a> [state\_bucket\_name](#input\_state\_bucket\_name) | S3 bucket that holds the Terraform state for every root module in this environment. | `string` | n/a | yes |
| <a name="input_state_key_prefix"></a> [state\_key\_prefix](#input\_state\_key\_prefix) | First path segment of the Terraform state keys, e.g. environments. | `string` | `"environments"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged into the default tag set applied to every resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster_addons"></a> [cluster\_addons](#output\_cluster\_addons) | Map of installed EKS add-ons and their versions. |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ARN of the EKS cluster. |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Base64 encoded certificate authority bundle for the cluster. |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Kubernetes API endpoint (private by default). |
| <a name="output_cluster_iam_role_arn"></a> [cluster\_iam\_role\_arn](#output\_cluster\_iam\_role\_arn) | ARN of the IAM role assumed by the EKS control plane. |
| <a name="output_cluster_kms_key_alias"></a> [cluster\_kms\_key\_alias](#output\_cluster\_kms\_key\_alias) | Alias of the Kubernetes secrets encryption key. |
| <a name="output_cluster_kms_key_arn"></a> [cluster\_kms\_key\_arn](#output\_cluster\_kms\_key\_arn) | ARN of the KMS key used for envelope encryption of Kubernetes secrets. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the EKS cluster. |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | Security group attached to the EKS control plane ENIs. |
| <a name="output_cluster_version"></a> [cluster\_version](#output\_cluster\_version) | Kubernetes version running on the control plane. |
| <a name="output_kubeconfig_secret_arn"></a> [kubeconfig\_secret\_arn](#output\_kubeconfig\_secret\_arn) | ARN of the Secrets Manager secret that holds the cluster kubeconfig. |
| <a name="output_node_group_ids"></a> [node\_group\_ids](#output\_node\_group\_ids) | Map of managed node group names to autoscaling group names. |
| <a name="output_node_security_group_id"></a> [node\_security\_group\_id](#output\_node\_security\_group\_id) | Security group attached to the managed node group ENIs. |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of the cluster OIDC provider used for IRSA roles. |
<!-- END_TF_DOCS -->
