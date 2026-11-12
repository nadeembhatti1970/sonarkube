# core-rds

Amazon RDS for PostgreSQL, sized and tuned for SonarQube, placed in the
isolated database subnets of `core-vpc`.

## Production posture

| Control | Value |
| :--- | :--- |
| Placement | DB subnet group from `core-vpc` (isolated subnets, no IGW/NAT route) |
| Public access | `publicly_accessible = false` |
| Availability | `multi_az = true` |
| Storage | gp3, 100 GiB -> 500 GiB autoscaling, 3000 IOPS, 250 MiB/s, CMK encrypted |
| Backups | 14 days, `02:00-03:00` UTC, final snapshot on destroy, deletion protection on |
| Monitoring | Enhanced Monitoring (60s), Performance Insights (7d, CMK), PostgreSQL + upgrade logs to encrypted CloudWatch (365 days) |
| Encryption in transit | `rds.force_ssl = 1`; the JDBC secret advertises `?sslmode=require` |
| Authentication | Secrets Manager master password + IAM database authentication enabled |
| Alerts | SNS (CMK) with CPU, freeable memory, free storage and connection alarms + RDS event subscription |

## Access control

PostgreSQL 5432 is allowed **only** from the `database-clients` security group
created in `core-vpc` and attached to the EKS managed node groups in `core-eks`:

```
aws_vpc_security_group_ingress_rule.postgres_from_clients
  referenced_security_group_id = <core-vpc database_client_security_group_id>
```

The RDS security group has no egress rules at all.

## Credentials without state

The master password is an **ephemeral** `random_password`: it exists in memory
during apply and is passed to AWS through write-only arguments only.

1. `core-secretsmanager` creates the secret containers (no versions).
2. This module generates the ephemeral password and sets
   `aws_db_instance.password_wo` with `password_wo_version`.
3. The same ephemeral value is written write-only to:
   * `rds/master` — JSON for DB tooling and the rotation Lambda,
   * `sonarqube/database` — full JDBC JSON.
4. External Secrets Operator (`core-external-secrets`) reads
   `sonarqube/database` at runtime and keeps the `sonarqube-db` Kubernetes
   Secret in sync. Terraform never reads the credential.

Nothing is persisted in state or plan files. `./scripts/check-secret-hygiene.sh`
fails the build if that ever changes.

## Usage

```bash
terraform init -backend-config=dev.tfbackend
terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

## Key inputs

| Name | Description | Default |
| :--- | :--- | :--- |
| `engine_version` | PostgreSQL version | `17.6` |
| `instance_class` | Instance class | `db.m6g.large` |
| `multi_az` | Multi-AZ standby | `true` |
| `deletion_protection` | Block API deletion | `true` |
| `skip_final_snapshot` | Skip the final snapshot | `false` |
| `backup_retention_days` | Backup window | `14` |
| `force_ssl` | Enforce TLS and advertise `sslmode` | `true` |
| `alarm_email` | Optional SNS email subscription | `null` |
| `performance_insights_retention_days` | PI retention tier | `7` |
| `db_username` / `db_name` / `db_port` | Database identity published to consumers | `sonar_admin` / `sonarqube` / `5432` |
| `db_password_revision` | Bump to rotate the ephemeral master password | `1` |

## Outputs

`db_instance_id`, `db_instance_arn`, `db_instance_address`, `db_instance_port`,
`db_name`, `db_username`, `db_security_group_id`, `parameter_group_name`,
`kms_key_arn`, `logs_kms_key_arn`, `database_secret_arn`,
`jdbc_url` (contains no credentials), `sslmode`, `alarm_topic_arn`.

## Notes

* Parameter changes use `apply_method = "pending-reboot"` because
  `shared_buffers`/`max_connections` are static parameters. Schedule the reboot
  in the maintenance window.
* Rotating the master password is a `db_password_revision` bump. The ephemeral
  password is regenerated and written to RDS and both secret versions in the
  same apply; External Secrets Operator refreshes the cluster within its
  interval, then restart the pod to pick it up.
* The optional Secrets Manager rotation Lambda changes the password
  out-of-band. Because every credential argument is write-only, Terraform does
  not detect or revert it; refresh the Kubernetes secret and restart SonarQube
  afterwards.
* Teardown requires disabling `deletion_protection` and accepting the final
  snapshot in a reviewed change (enforced by `scripts/plan-guard.sh`).

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

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.postgresql](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.upgrade](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.connections_high](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.cpu_high](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.free_storage_low](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.freeable_memory_low](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_db_event_subscription.sonarqube](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_event_subscription) | resource |
| [aws_db_instance.sonarqube](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_parameter_group.sonarqube](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) | resource |
| [aws_iam_role.rds_enhanced_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.rds_enhanced_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.alarms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_alias.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_alias.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.alarms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_secretsmanager_secret_version.rds_master](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.sonarqube_database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_security_group.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_sns_topic.database_alarms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.database_alarms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.database_alarms_email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_vpc_security_group_ingress_rule.postgres_from_clients](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.rds_enhanced_monitoring_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [terraform_remote_state.secretsmanager](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |
| [terraform_remote_state.vpc](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alarm_email"></a> [alarm\_email](#input\_alarm\_email) | Optional email address subscribed to the database alarm topic. | `string` | `null` | no |
| <a name="input_allocated_storage"></a> [allocated\_storage](#input\_allocated\_storage) | Initial gp3 storage allocation in GiB. | `number` | `100` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region that hosts the RDS instance. | `string` | `"eu-west-1"` | no |
| <a name="input_backup_retention_days"></a> [backup\_retention\_days](#input\_backup\_retention\_days) | Automated backup retention period in days (0 disables backups). | `number` | `14` | no |
| <a name="input_backup_window"></a> [backup\_window](#input\_backup\_window) | UTC window for automated backups (must not overlap the maintenance window). | `string` | `"02:00-03:00"` | no |
| <a name="input_ca_cert_identifier"></a> [ca\_cert\_identifier](#input\_ca\_cert\_identifier) | RDS certificate authority used for TLS connections from SonarQube. | `string` | `"rds-ca-rsa2048-g1"` | no |
| <a name="input_cpu_alarm_threshold_percent"></a> [cpu\_alarm\_threshold\_percent](#input\_cpu\_alarm\_threshold\_percent) | CPU utilisation percentage that triggers the sustained CPU alarm. | `number` | `80` | no |
| <a name="input_db_name"></a> [db\_name](#input\_db\_name) | Initial database created for SonarQube. | `string` | `"sonarqube"` | no |
| <a name="input_db_password_length"></a> [db\_password\_length](#input\_db\_password\_length) | Length of the ephemeral master password generated on each credential rotation. | `number` | `32` | no |
| <a name="input_db_password_revision"></a> [db\_password\_revision](#input\_db\_password\_revision) | Bump to rotate the master password. The new password is ephemeral and is only written to RDS/Secrets Manager through write-only arguments. | `number` | `1` | no |
| <a name="input_db_port"></a> [db\_port](#input\_db\_port) | TCP port PostgreSQL listens on inside the VPC. | `number` | `5432` | no |
| <a name="input_db_username"></a> [db\_username](#input\_db\_username) | Master username for the SonarQube PostgreSQL instance. | `string` | `"sonar_admin"` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Block deletion of the database via the API. Must be disabled deliberately during teardown. | `bool` | `true` | no |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | PostgreSQL engine version for the SonarQube database. | `string` | `"17.6"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (dev, staging, prod). | `string` | n/a | yes |
| <a name="input_force_ssl"></a> [force\_ssl](#input\_force\_ssl) | Set rds.force\_ssl=1 on the parameter group and advertise sslmode=require in the JDBC URL. | `bool` | `true` | no |
| <a name="input_free_storage_alarm_threshold_bytes"></a> [free\_storage\_alarm\_threshold\_bytes](#input\_free\_storage\_alarm\_threshold\_bytes) | Free storage threshold in bytes below which the storage alarm fires. | `number` | `21474836480` | no |
| <a name="input_freeable_memory_alarm_threshold_bytes"></a> [freeable\_memory\_alarm\_threshold\_bytes](#input\_freeable\_memory\_alarm\_threshold\_bytes) | Freeable memory threshold in bytes below which the memory alarm fires. | `number` | `536870912` | no |
| <a name="input_instance_class"></a> [instance\_class](#input\_instance\_class) | RDS instance class. SonarQube benefits from memory and burst IOPS, so m-class Graviton is the default. | `string` | `"db.m6g.large"` | no |
| <a name="input_kms_deletion_window_in_days"></a> [kms\_deletion\_window\_in\_days](#input\_kms\_deletion\_window\_in\_days) | Waiting period before the RDS storage and log KMS keys are destroyed after scheduling deletion. | `number` | `30` | no |
| <a name="input_log_retention_in_days"></a> [log\_retention\_in\_days](#input\_log\_retention\_in\_days) | Retention for the PostgreSQL and upgrade log groups exported to CloudWatch Logs. | `number` | `365` | no |
| <a name="input_maintenance_window"></a> [maintenance\_window](#input\_maintenance\_window) | UTC window for RDS maintenance (must not overlap the backup window). | `string` | `"sun:04:00-sun:05:00"` | no |
| <a name="input_max_allocated_storage"></a> [max\_allocated\_storage](#input\_max\_allocated\_storage) | Upper bound for RDS storage autoscaling in GiB (0 disables autoscaling). | `number` | `500` | no |
| <a name="input_max_connections_alarm_threshold"></a> [max\_connections\_alarm\_threshold](#input\_max\_connections\_alarm\_threshold) | Database connection count above which the connection alarm fires. | `number` | `180` | no |
| <a name="input_monitoring_interval"></a> [monitoring\_interval](#input\_monitoring\_interval) | Enhanced Monitoring interval in seconds (0, 1, 5, 10, 15, 30 or 60). | `number` | `60` | no |
| <a name="input_multi_az"></a> [multi\_az](#input\_multi\_az) | Deploy a synchronous standby in a second AZ. Required for production grade resilience. | `bool` | `true` | no |
| <a name="input_performance_insights_retention_days"></a> [performance\_insights\_retention\_days](#input\_performance\_insights\_retention\_days) | Performance Insights retention period in days (7 is the free tier, 465 the long-term tier). | `number` | `7` | no |
| <a name="input_project"></a> [project](#input\_project) | Short project identifier used to build resource names and tags. | `string` | n/a | yes |
| <a name="input_skip_final_snapshot"></a> [skip\_final\_snapshot](#input\_skip\_final\_snapshot) | Skip the final snapshot on destroy. Only acceptable for disposable environments. | `bool` | `false` | no |
| <a name="input_state_bucket_name"></a> [state\_bucket\_name](#input\_state\_bucket\_name) | S3 bucket that holds the Terraform state for every root module in this environment. | `string` | n/a | yes |
| <a name="input_state_key_prefix"></a> [state\_key\_prefix](#input\_state\_key\_prefix) | First path segment of the Terraform state keys, e.g. environments. | `string` | `"environments"` | no |
| <a name="input_storage_iops"></a> [storage\_iops](#input\_storage\_iops) | Provisioned IOPS for the gp3 volume. | `number` | `3000` | no |
| <a name="input_storage_throughput"></a> [storage\_throughput](#input\_storage\_throughput) | Provisioned throughput in MiB/s for the gp3 volume. | `number` | `250` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged into the default tag set applied to every resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alarm_topic_arn"></a> [alarm\_topic\_arn](#output\_alarm\_topic\_arn) | ARN of the SNS topic that receives database alarms and RDS events. |
| <a name="output_database_secret_arn"></a> [database\_secret\_arn](#output\_database\_secret\_arn) | ARN of the JDBC JSON secret consumed by External Secrets Operator deployments. |
| <a name="output_db_instance_address"></a> [db\_instance\_address](#output\_db\_instance\_address) | DNS name of the database endpoint (private, resolvable only inside the VPC). |
| <a name="output_db_instance_arn"></a> [db\_instance\_arn](#output\_db\_instance\_arn) | ARN of the SonarQube PostgreSQL instance. |
| <a name="output_db_instance_id"></a> [db\_instance\_id](#output\_db\_instance\_id) | Identifier of the SonarQube PostgreSQL instance. |
| <a name="output_db_instance_port"></a> [db\_instance\_port](#output\_db\_instance\_port) | TCP port the database listens on. |
| <a name="output_db_name"></a> [db\_name](#output\_db\_name) | Initial database name used by SonarQube. |
| <a name="output_db_security_group_id"></a> [db\_security\_group\_id](#output\_db\_security\_group\_id) | Security group guarding the database. Only the database-clients group may connect. |
| <a name="output_db_username"></a> [db\_username](#output\_db\_username) | Master username used by SonarQube. The password lives only in Secrets Manager. |
| <a name="output_jdbc_url"></a> [jdbc\_url](#output\_jdbc\_url) | JDBC URL SonarQube should use to reach the database (no credentials embedded). |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN of the key that encrypts the database volume and snapshots. |
| <a name="output_logs_kms_key_arn"></a> [logs\_kms\_key\_arn](#output\_logs\_kms\_key\_arn) | ARN of the key that encrypts exported PostgreSQL logs. |
| <a name="output_parameter_group_name"></a> [parameter\_group\_name](#output\_parameter\_group\_name) | Name of the SonarQube tuned parameter group. |
| <a name="output_sslmode"></a> [sslmode](#output\_sslmode) | TLS mode advertised to the JDBC driver. |
<!-- END_TF_DOCS -->
