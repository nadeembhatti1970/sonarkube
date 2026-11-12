# core-external-secrets

Installs the External Secrets Operator (ESO) and the `aws-secretsmanager`
ClusterSecretStore that the application modules use. This is the runtime path
for credentials: Terraform writes secret versions to AWS Secrets Manager,
ESO keeps the Kubernetes Secrets in sync, and no credential is ever read by
Terraform.

## What it creates

| Resource | Purpose |
| :--- | :--- |
| `helm_release.external_secrets` | Official `external-secrets` chart, pinned to `2.15.0`, CRDs installed, dedicated namespace |
| `aws_iam_role.external_secrets` | Controller role trusted by `pods.eks.amazonaws.com` (EKS Pod Identity) |
| `aws_iam_policy.read_secrets` | `secretsmanager:GetSecretValue`/`DescribeSecret`/`ListSecretVersionIds` on the platform's seven secret ARNs only, plus `kms:Decrypt`/`DescribeKey` on the secrets CMK |
| `aws_eks_pod_identity_association.external_secrets` | Binds the `external-secrets` service account to the role |
| `helm_release.secret_store` | In-repo chart `helm/external-secrets-store` that creates the `ClusterSecretStore` |

## Why Pod Identity

* No static AWS credentials, no access keys in Kubernetes.
* The role is scoped to exact secret ARNs and the one CMK — not `*`.
* The association is the only binding between Kubernetes identity and AWS IAM,
  so revoking it is a single, auditable operation.
* The store itself has **no auth block**: ESO picks up the Pod Identity
  credentials from the AWS SDK default chain.

## Why a Helm chart for the store

`kubernetes_manifest` would need the CRDs to exist at *plan* time, which they do
not on the first apply (ESO installs them during apply). The store is applied by
Helm after the operator release, so a clean install happens in one pass. The
same pattern is used for the SonarQube ExternalSecrets.

## Usage

Apply **after** `core-eks` and `core-secretsmanager`, and **before**
`core-sonarqube`:

```bash
terraform init -backend-config=dev.tfbackend
terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

## Key inputs

| Name | Description | Default |
| :--- | :--- | :--- |
| `namespace` | Controller namespace | `external-secrets` |
| `service_account_name` | Service account bound to the IAM role | `external-secrets` |
| `chart_version` | Pinned ESO chart version | `2.15.0` |
| `replica_count` | Controller replicas | `1` |
| `secret_store_name` | ClusterSecretStore name used by apps | `aws-secretsmanager` |
| `helm_timeout_seconds` | Helm timeout | `600` |

## Outputs

`namespace`, `release_name`, `chart_version`, `service_account_name`,
`iam_role_arn`, `secret_store_name`.

## Verification

```bash
# Controller is running
kubectl -n external-secrets get pods

# Store reports Valid
kubectl get clustersecretstore aws-secretsmanager -o jsonpath='{.status.conditions}'

# Application secret is synced
kubectl -n sonarqube get externalsecret
kubectl -n sonarqube get secret sonarqube-db
```

## Rotation

Rotation is driven by the secret versions in Secrets Manager (see
`core-secretsmanager` and `core-rds`). ESO re-reads every
`refreshInterval`; the SonarQube module exposes that as
`external_secrets_refresh_interval`. Restart the SonarQube pod after a database
password rotation so it rebuilds its JDBC pool.

## Notes

* The chart's webhook and cert-controller run in the same namespace; they only
  validate ESO custom resources.
* `helm_release` installs CRDs with `installCRDs = true`. CRDs are not removed
  by a Terraform destroy (Helm does not delete CRDs), which is intentional.
* The controller's IAM policy is exported as `iam_role_arn` if another stack
  needs to reference it for audit tooling.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.73.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.3.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_eks_pod_identity_association.external_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association) | resource |
| [aws_iam_policy.read_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.external_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.read_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [helm_release.external_secrets](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.secret_store](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.read_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [terraform_remote_state.eks](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |
| [terraform_remote_state.secretsmanager](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region that hosts the EKS cluster and Secrets Manager. | `string` | `"eu-west-1"` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Pinned version of the external-secrets Helm chart. | `string` | `"2.15.0"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (dev, staging, prod). | `string` | n/a | yes |
| <a name="input_helm_timeout_seconds"></a> [helm\_timeout\_seconds](#input\_helm\_timeout\_seconds) | Time, in seconds, Terraform waits for each Helm release. | `number` | `600` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace for the External Secrets Operator controller. | `string` | `"external-secrets"` | no |
| <a name="input_project"></a> [project](#input\_project) | Short project identifier used to build resource names and tags. | `string` | n/a | yes |
| <a name="input_replica_count"></a> [replica\_count](#input\_replica\_count) | Controller replica count. | `number` | `1` | no |
| <a name="input_secret_store_name"></a> [secret\_store\_name](#input\_secret\_store\_name) | Name of the cluster-wide ClusterSecretStore used by application modules. | `string` | `"aws-secretsmanager"` | no |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Service account used by the controller and bound to the IAM role through EKS Pod Identity. | `string` | `"external-secrets"` | no |
| <a name="input_state_bucket_name"></a> [state\_bucket\_name](#input\_state\_bucket\_name) | S3 bucket that holds the Terraform state for every root module in this environment. | `string` | n/a | yes |
| <a name="input_state_key_prefix"></a> [state\_key\_prefix](#input\_state\_key\_prefix) | First path segment of the Terraform state keys, e.g. environments. | `string` | `"environments"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged into the default tag set applied to every AWS resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_chart_version"></a> [chart\_version](#output\_chart\_version) | Pinned external-secrets chart version. |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | ARN of the IAM role used by the controller (Pod Identity). |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Namespace that runs the External Secrets Operator. |
| <a name="output_release_name"></a> [release\_name](#output\_release\_name) | Name of the External Secrets Operator Helm release. |
| <a name="output_secret_store_name"></a> [secret\_store\_name](#output\_secret\_store\_name) | Name of the ClusterSecretStore that application modules reference. |
| <a name="output_service_account_name"></a> [service\_account\_name](#output\_service\_account\_name) | Service account bound to the controller IAM role. |
<!-- END_TF_DOCS -->