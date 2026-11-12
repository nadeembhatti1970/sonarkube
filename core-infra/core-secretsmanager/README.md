# core-secretsmanager

Owns every credential and key the platform needs, in one place, under one
customer managed KMS key. **No secret value is ever persisted by Terraform**:
values are generated as *ephemeral* resources and written with the provider's
write-only arguments, so state and plan files contain only secret metadata
(ARNs, names, version counters).

## Secret inventory

| Secret name (`<project>-<env>/...`) | Version writer | Contents |
| :--- | :--- | :--- |
| `rds/master` | core-rds | `engine`, `username`, `password`, `dbname`, `port` (JSON) |
| `sonarqube/database` | core-rds | full JDBC JSON for External Secrets Operator consumers |
| `sonarqube/admin-current-password` | this module | previous administrator password (chart `setAdminPassword` hook) |
| `sonarqube/admin-password` | this module | generated administrator password |
| `sonarqube/monitoring-passcode` | this module | health-endpoint passcode |
| `sonarqube/server-secret-key` | this module | `sonar-secret.txt` server-side encryption key |
| `kubernetes/kubeconfig` | core-eks | kubeconfig using `aws eks get-token` (no static token) |

Each secret has exactly one version writer, so modules cannot fight over the
current version. Empty containers are created here; versions are written by the
owning module.

## No secrets in state

```hcl
ephemeral "random_password" "sonarqube_admin" { length = 32 }

resource "aws_secretsmanager_secret_version" "sonarqube_admin_password" {
  secret_id                = aws_secretsmanager_secret.sonarqube_admin_password.id
  secret_string_wo         = ephemeral.random_password.sonarqube_admin.result
  secret_string_wo_version = var.sonarqube_credentials_version
}
```

* `ephemeral` values exist in memory during apply only.
* `secret_string_wo` is write-only: the provider sends it to AWS and never
  returns or stores it.
* `secret_string_wo_version` is the only thing in state; bumping it rewrites
  the value (rotation).
* Application modules do not read the values at all: External Secrets Operator
  syncs them into Kubernetes with its own Pod Identity role. The kubeconfig
  secret is the only version Terraform reads back, and only for cluster
  consumers, never for credentials.

`./scripts/check-secret-hygiene.sh` enforces this statically (no
`random_password` resources, no `secret_string =`, no
`data "aws_secretsmanager_secret_version"`, no plain `password =`, and every
write-only attribute paired with a version).

## Usage

```bash
terraform init -backend-config=dev.tfbackend
terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

## Key inputs

| Name | Description | Default |
| :--- | :--- | :--- |
| `sonarqube_admin_password_length` | Generated admin password length | `32` |
| `sonarqube_credentials_version` | Rotation counter for the three SonarQube secrets | `1` |
| `secret_recovery_window_in_days` | Deletion recovery window | `30` |
| `enable_rds_master_rotation` | Wire Secrets Manager rotation for `rds/master` | `false` |
| `rds_master_rotation_lambda_arn` | Rotation Lambda (required when enabled) | `null` |
| `kms_deletion_window_in_days` | Secrets key deletion window | `30` |

## Rotation

**Terraform-driven (default).** Bump the revision, apply, then push the new
value to the cluster and restart the consumer:

1. `core-rds`: `db_password_revision += 1` — regenerates the ephemeral master
   password, updates RDS via `password_wo`, and rewrites the `rds/master` and
   `sonarqube/database` secret versions.
2. `core-secretsmanager`: `sonarqube_credentials_version += 1` — regenerates the
   admin password, passcode and server key.
3. Update the `sonarqube/admin-current-password` secret with the previous
   password when rotating the admin credential (`TF_VAR_sonarqube_current_admin_password`
   on the `core-secretsmanager` apply), then let ESO refresh and restart the
   SonarQube pod so it rebuilds its JDBC pool.

**External rotation Lambda (optional).** `rds/master` rotation can be delegated
to a VPC-attached Lambda. Because RDS and the secret are write-only, Terraform
does not detect or revert out-of-band rotation. External Secrets Operator picks
up the new value within its refresh interval; restart SonarQube afterwards so it
rebuilds its JDBC connection pool.

## Notes

* All generated passwords exclude characters that break JDBC URLs and shell
  quoting (`"`, `'`, `\`, `@`, `:`, `/`).
* The CMK policy grants the account root only; access is governed by IAM
  (IRSA, pod identity, CI roles and break-glass).
* External Secrets Operator (installed by `core-external-secrets`) reads these
  secrets at runtime through the `aws-secretsmanager` ClusterSecretStore. To
  rotate, bump `sonarqube_credentials_version` (or `db_password_revision` in
  `core-rds`) and let ESO refresh; no Kubernetes secret is written by
  Terraform.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.7 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.73.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_kms_alias.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_secretsmanager_secret.kubernetes_kubeconfig](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.rds_master](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.sonarqube_admin_current_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.sonarqube_admin_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.sonarqube_database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.sonarqube_monitoring_passcode](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.sonarqube_server_secret_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_rotation.rds_master](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_rotation) | resource |
| [aws_secretsmanager_secret_version.sonarqube_admin_current_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.sonarqube_admin_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.sonarqube_monitoring_passcode](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.sonarqube_server_secret_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region that hosts the Secrets Manager secrets. | `string` | `"eu-west-1"` | no |
| <a name="input_enable_rds_master_rotation"></a> [enable\_rds\_master\_rotation](#input\_enable\_rds\_master\_rotation) | Enable automatic rotation of the RDS master secret. Requires a VPC-attached rotation Lambda (see README). | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (dev, staging, prod). | `string` | n/a | yes |
| <a name="input_kms_deletion_window_in_days"></a> [kms\_deletion\_window\_in\_days](#input\_kms\_deletion\_window\_in\_days) | Waiting period before the secrets KMS key is destroyed after scheduling deletion. | `number` | `30` | no |
| <a name="input_project"></a> [project](#input\_project) | Short project identifier used to build resource names and tags. | `string` | n/a | yes |
| <a name="input_rds_master_rotation_days"></a> [rds\_master\_rotation\_days](#input\_rds\_master\_rotation\_days) | Rotation interval, in days, for the RDS master secret. | `number` | `30` | no |
| <a name="input_rds_master_rotation_lambda_arn"></a> [rds\_master\_rotation\_lambda\_arn](#input\_rds\_master\_rotation\_lambda\_arn) | ARN of the rotation Lambda invoked by Secrets Manager when rotation is enabled. | `string` | `null` | no |
| <a name="input_secret_recovery_window_in_days"></a> [secret\_recovery\_window\_in\_days](#input\_secret\_recovery\_window\_in\_days) | Recovery window for deleted secrets (0 disables recovery and is not recommended). | `number` | `30` | no |
| <a name="input_sonarqube_admin_password_length"></a> [sonarqube\_admin\_password\_length](#input\_sonarqube\_admin\_password\_length) | Length of the generated SonarQube local administrator password. | `number` | `32` | no |
| <a name="input_sonarqube_credentials_version"></a> [sonarqube\_credentials\_version](#input\_sonarqube\_credentials\_version) | Bump to rotate the SonarQube admin password, monitoring passcode and server encryption key. Write-only values are only rewritten when this number changes. | `number` | `1` | no |
| <a name="input_sonarqube_current_admin_password"></a> [sonarqube\_current\_admin\_password](#input\_sonarqube\_current\_admin\_password) | Administrator password currently in use, consumed by the chart's setAdminPassword hook. Defaults to the SonarQube bootstrap password and is supplied via TF\_VAR\_ on rotation. | `string` | `"admin"` | no |
| <a name="input_state_bucket_name"></a> [state\_bucket\_name](#input\_state\_bucket\_name) | S3 bucket that holds the Terraform state for every root module in this environment. | `string` | n/a | yes |
| <a name="input_state_key_prefix"></a> [state\_key\_prefix](#input\_state\_key\_prefix) | First path segment of the Terraform state keys, e.g. environments. | `string` | `"environments"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged into the default tag set applied to every resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_kms_key_alias"></a> [kms\_key\_alias](#output\_kms\_key\_alias) | Alias of the key that encrypts application secrets. |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN of the customer managed key that encrypts every application secret. |
| <a name="output_kubernetes_kubeconfig_secret_arn"></a> [kubernetes\_kubeconfig\_secret\_arn](#output\_kubernetes\_kubeconfig\_secret\_arn) | ARN of the secret that core-eks populates with the cluster kubeconfig. |
| <a name="output_kubernetes_kubeconfig_secret_name"></a> [kubernetes\_kubeconfig\_secret\_name](#output\_kubernetes\_kubeconfig\_secret\_name) | Name of the secret that core-eks populates with the cluster kubeconfig. |
| <a name="output_rds_master_secret_arn"></a> [rds\_master\_secret\_arn](#output\_rds\_master\_secret\_arn) | ARN of the secret container for the RDS master credentials (version written by core-rds). |
| <a name="output_rds_master_secret_name"></a> [rds\_master\_secret\_name](#output\_rds\_master\_secret\_name) | Name of the secret container for the RDS master credentials. |
| <a name="output_secret_arns"></a> [secret\_arns](#output\_secret\_arns) | Map of logical secret name to Secrets Manager ARN, used to scope the External Secrets Operator IAM policy. |
| <a name="output_sonarqube_admin_current_password_secret_arn"></a> [sonarqube\_admin\_current\_password\_secret\_arn](#output\_sonarqube\_admin\_current\_password\_secret\_arn) | ARN of the secret holding the previous (currently active) administrator password. |
| <a name="output_sonarqube_admin_current_password_secret_name"></a> [sonarqube\_admin\_current\_password\_secret\_name](#output\_sonarqube\_admin\_current\_password\_secret\_name) | Name of the secret holding the previous (currently active) administrator password. |
| <a name="output_sonarqube_admin_password_secret_arn"></a> [sonarqube\_admin\_password\_secret\_arn](#output\_sonarqube\_admin\_password\_secret\_arn) | ARN of the secret holding the SonarQube administrator password. |
| <a name="output_sonarqube_admin_password_secret_name"></a> [sonarqube\_admin\_password\_secret\_name](#output\_sonarqube\_admin\_password\_secret\_name) | Name of the secret holding the SonarQube administrator password. |
| <a name="output_sonarqube_database_secret_arn"></a> [sonarqube\_database\_secret\_arn](#output\_sonarqube\_database\_secret\_arn) | ARN of the JDBC JSON secret consumed by External Secrets Operator. |
| <a name="output_sonarqube_database_secret_name"></a> [sonarqube\_database\_secret\_name](#output\_sonarqube\_database\_secret\_name) | Name of the JDBC JSON secret consumed by External Secrets Operator. |
| <a name="output_sonarqube_monitoring_passcode_secret_arn"></a> [sonarqube\_monitoring\_passcode\_secret\_arn](#output\_sonarqube\_monitoring\_passcode\_secret\_arn) | ARN of the secret holding the SonarQube monitoring passcode. |
| <a name="output_sonarqube_monitoring_passcode_secret_name"></a> [sonarqube\_monitoring\_passcode\_secret\_name](#output\_sonarqube\_monitoring\_passcode\_secret\_name) | Name of the secret holding the SonarQube monitoring passcode. |
| <a name="output_sonarqube_server_secret_key_secret_arn"></a> [sonarqube\_server\_secret\_key\_secret\_arn](#output\_sonarqube\_server\_secret\_key\_secret\_arn) | ARN of the secret holding the SonarQube server-side encryption key (sonar-secret.txt). |
| <a name="output_sonarqube_server_secret_key_secret_name"></a> [sonarqube\_server\_secret\_key\_secret\_name](#output\_sonarqube\_server\_secret\_key\_secret\_name) | Name of the secret holding the SonarQube server-side encryption key (sonar-secret.txt). |
<!-- END_TF_DOCS -->