# core-sonarqube

Deploys the SonarQube Community Build with the official SonarSource Helm chart
(`sonarqube/sonarqube`, pinned) and wires it to the private RDS instance.

Credentials are **not** handled by Terraform: External Secrets Operator
(`core-external-secrets`) reads AWS Secrets Manager and maintains the Kubernetes
Secrets that the chart references.

## What it creates

| Object | Purpose |
| :--- | :--- |
| `kubernetes_namespace_v1.sonarqube` | Dedicated namespace with Pod Security labels |
| `kubernetes_storage_class_v1.ebs_gp3` | Default gp3 class backed by the EBS CSI driver (encrypted, expandable, `WaitForFirstConsumer`) |
| `helm_release.sonarqube_secrets` | Installs `helm/sonarqube-secrets`: ExternalSecrets that create `sonarqube-db` and `sonarqube-admin` from Secrets Manager |
| `helm_release.sonarqube` | Chart `2026.5.1004`, StatefulSet, PVC, external JDBC, optional Ingress; depends on the ExternalSecrets |

## Chart configuration highlights

The chart (>= 2026.5) requires an explicit edition: Community Build is selected
with `community.enabled: true` and no `edition` value. This is set in
`base_values` and asserted in the unit tests.

```yaml
jdbcOverwrite:
  enabled: true
  jdbcUrl: jdbc:postgresql://<rds-endpoint>:5432/sonarqube?sslmode=require
  jdbcUsername: sonar_admin
  jdbcSecretName: sonarqube-db          # password referenced, never inlined
  jdbcSecretPasswordKey: password
monitoringPasscodeSecretName: sonarqube-admin
sonarSecretKey: sonarqube-admin         # key sonar-secret.txt
setAdminPassword:
  passwordSecretName: sonarqube-admin   # keys password + currentPassword
persistence:
  enabled: true
  storageClass: ebs-gp3
  size: 20Gi
resources:
  requests: { cpu: "1", memory: 4Gi }
  limits:   { cpu: "2", memory: 8Gi }
```

The chart's `initSysctl` container needs privileged mode to raise
`vm.max_map_count`/`fs.file-max` inside the pod, which is why the namespace
enforces `pod-security.kubernetes.io/enforce: privileged`. The audit and warn
labels stay at `restricted`, the container itself is unprivileged, and the
service account token is not mounted.

## Ingress

Disabled by default because the AWS Load Balancer Controller is a separate
lifecycle. When enabled (`ingress_enabled = true`), the values include internal
ALB annotations and a health check on `/api/system/status`. Supply the ACM
certificate ARN through `ingress_annotations`.

## Secrets via External Secrets Operator

Terraform installs two ExternalSecret resources (in-repo chart
`helm/sonarqube-secrets`) and never reads a credential:

```yaml
# sonarqube-db
spec:
  secretStoreRef: { name: aws-secretsmanager, kind: ClusterSecretStore }
  target: { name: sonarqube-db, creationPolicy: Owner, deletionPolicy: Retain }
  dataFrom:
    - extract: { key: sonarkube-dev/sonarqube/database }

# sonarqube-admin
spec:
  data:
    - { secretKey: password,        remoteRef: { key: sonarkube-dev/sonarqube/admin-password } }
    - { secretKey: currentPassword, remoteRef: { key: sonarkube-dev/sonarqube/admin-current-password } }
    - { secretKey: passcode,        remoteRef: { key: sonarkube-dev/sonarqube/monitoring-passcode } }
    - { secretKey: sonar-secret.txt, remoteRef: { key: sonarkube-dev/sonarqube/server-secret-key } }
```

* ESO authenticates with **EKS Pod Identity** (role created by
  `core-external-secrets`); there are no AWS credentials in the cluster.
* `deletionPolicy: Retain` keeps the Kubernetes Secret if the ExternalSecret is
  removed, so a bad rollout cannot strip credentials from a running pod.
* Rotation is picked up within `external_secrets_refresh_interval` (`1h` by
  default) without a Terraform apply. SonarQube still needs a pod restart to
  rebuild its JDBC pool after a database password change.

Terraform state contains no credential material; the chart still consumes
secrets by *reference* only (`jdbcSecretName`, `monitoringPasscodeSecretName`,
`sonarSecretKey`, `setAdminPassword.passwordSecretName`).

## Usage, validation and tests

Requires `core-eks`, `core-rds`, `core-secretsmanager` and `core-external-secrets` states to exist. The cluster endpoint is private and the providers use `aws eks get-token`, so plan/apply must run from inside the VPC. Apply `core-external-secrets` before this module so the ExternalSecret CRDs and ClusterSecretStore exist.

Run these commands from this module directory. State configuration comes from
`dev.tfbackend` (where applicable); environment inputs come from `dev.tfvars`.

```bash
# 1. Initialise the partial S3 backend
terraform init -backend-config=dev.tfbackend

# 2. Check formatting and configuration
terraform fmt -check -recursive .
terraform validate

# 3. Plan with the environment inputs
#    (requires AWS credentials; later layers also need their upstream states)
terraform plan -var-file=dev.tfvars -out=tfplan

# 4. Run the native tests (mocked providers, no AWS calls)
terraform test -test-directory=testing

# 5. Static analysis: run from the repository root so .checkov.yaml applies
#    (from this module directory: cd ../.. first)
checkov -d core-infra/core-sonarqube

# 6. Apply the reviewed plan
terraform apply tfplan
# or, without a saved plan:
terraform apply -var-file=dev.tfvars
```

The repository-level wrappers run the same gates across all modules:

```bash
./scripts/validate.sh                        # fmt, validate, secret hygiene, checkov and tests
./scripts/plan-guard.sh core-infra/core-sonarqube               # plan JSON, Checkov terraform_plan and destroy gate
```

`plan-guard.sh` needs AWS credentials and state access; `terraform test` does not.

## Key inputs

| Name | Description | Default |
| :--- | :--- | :--- |
| `namespace` | Target namespace | `sonarqube` |
| `chart_version` | Pinned chart version | `2026.5.1004` |
| `storage_class_name` / `persistence_size` | Volume configuration | `ebs-gp3` / `20Gi` |
| `cpu_request` / `memory_request` / `cpu_limit` / `memory_limit` | Container resources | `1` / `4Gi` / `2` / `8Gi` |
| `ingress_enabled` / `ingress_host` | ALB ingress toggle and host | `false` / `sonarqube.dev.sonarkube.internal` |
| `ingress_annotations` | Extra ingress annotations (ACM ARN, WAF, ...) | `{}` |
| `external_secrets_store_name` | ClusterSecretStore referenced by the ExternalSecrets | `aws-secretsmanager` |
| `external_secrets_refresh_interval` | ESO re-read interval | `1h` |
| `sonar_properties` | Extra `sonar.properties` entries | `{}` |

The ExternalSecrets require `core-external-secrets` to be applied first; also
set `external_secrets_refresh_interval` to match how quickly you expect a
rotation to reach the cluster.

## Outputs

`namespace`, `release_name`, `release_version`, `chart_version`, `service_name`,
`ingress_host`, `database_secret_name`, `admin_secret_name`,
`storage_class_name`, `database_endpoint`, `status`.

## First login and admin password

`setAdminPassword` sets the admin password from the `sonarqube-admin` secret on
first boot (`currentPassword` comes from the `admin-current-password` secret,
initially `admin`, and `password` from `admin-password`):

```bash
kubectl -n sonarqube get secret sonarqube-admin -o jsonpath='{.data.password}' | base64 -d; echo
```

`setAdminPassword` runs as a Helm post-install/post-upgrade hook. Before any
later chart upgrade or credential rotation, update the
`sonarqube/admin-current-password` secret in Secrets Manager (or apply
`core-secretsmanager` with `TF_VAR_sonarqube_current_admin_password='<current>'`
and a bumped `sonarqube_credentials_version`), let ESO refresh, then restart the
StatefulSet. Otherwise the hook cannot authenticate and the release upgrade
fails.

Supply the current password through a sensitive variable (`TF_VAR_...`), never a
committed tfvars file; it is written write-only and never stored in state. If
you prefer to manage the administrator password entirely out of band, omit
`setAdminPassword` from `local.base_values` in `sonarqube.tf`.

## Notes

* One replica only: SonarQube Community Build does not support horizontal
  scaling (`replicaCount: 1`).
* Helm installs are `atomic`, `wait`, `wait_for_jobs` with a 15 minute timeout so
  the database migration completes before Terraform reports success.
* The chart's smoke-test pod is disabled for deterministic, air-gapped installs.

## Reference

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 3.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.3.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 3.5.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.sonarqube](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.sonarqube_secrets](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace_v1.sonarqube](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_storage_class_v1.ebs_gp3](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/storage_class_v1) | resource |
| [terraform_remote_state.eks](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |
| [terraform_remote_state.rds](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |
| [terraform_remote_state.secretsmanager](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region that hosts the EKS cluster. | `string` | `"eu-west-1"` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Pinned version of the official SonarSource sonarqube Helm chart. | `string` | `"2026.5.1004"` | no |
| <a name="input_cpu_limit"></a> [cpu\_limit](#input\_cpu\_limit) | CPU limit for the SonarQube container. | `string` | `"2"` | no |
| <a name="input_cpu_request"></a> [cpu\_request](#input\_cpu\_request) | CPU request for the SonarQube container. | `string` | `"1"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (dev, staging, prod). | `string` | n/a | yes |
| <a name="input_external_secrets_refresh_interval"></a> [external\_secrets\_refresh\_interval](#input\_external\_secrets\_refresh\_interval) | How often External Secrets Operator re-reads the SonarQube secrets (for example 1m, 15m, 1h). | `string` | `"1h"` | no |
| <a name="input_external_secrets_store_name"></a> [external\_secrets\_store\_name](#input\_external\_secrets\_store\_name) | ClusterSecretStore created by core-external-secrets and referenced by the SonarQube ExternalSecrets. | `string` | `"aws-secretsmanager"` | no |
| <a name="input_helm_timeout_seconds"></a> [helm\_timeout\_seconds](#input\_helm\_timeout\_seconds) | Time, in seconds, Terraform waits for the Helm release to become ready. | `number` | `900` | no |
| <a name="input_ingress_annotations"></a> [ingress\_annotations](#input\_ingress\_annotations) | Additional annotations merged into the Ingress object (e.g. ALB listen-ports, ACM certificate ARN). | `map(string)` | `{}` | no |
| <a name="input_ingress_class_name"></a> [ingress\_class\_name](#input\_ingress\_class\_name) | Ingress class used when ingress\_enabled is true (alb, nginx, ...). | `string` | `"alb"` | no |
| <a name="input_ingress_enabled"></a> [ingress\_enabled](#input\_ingress\_enabled) | Create an Ingress for SonarQube. Requires an installed ingress controller (ALB or nginx). | `bool` | `false` | no |
| <a name="input_ingress_host"></a> [ingress\_host](#input\_ingress\_host) | DNS name published in the Ingress rule. | `string` | `"sonarqube.dev.sonarkube.internal"` | no |
| <a name="input_ingress_tls_secret_name"></a> [ingress\_tls\_secret\_name](#input\_ingress\_tls\_secret\_name) | Optional TLS secret name for the Ingress. ALB users usually prefer the ACM certificate annotation instead. | `string` | `null` | no |
| <a name="input_memory_limit"></a> [memory\_limit](#input\_memory\_limit) | Memory limit for the SonarQube container. | `string` | `"8Gi"` | no |
| <a name="input_memory_request"></a> [memory\_request](#input\_memory\_request) | Memory request for the SonarQube container. | `string` | `"4Gi"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace that hosts SonarQube. | `string` | `"sonarqube"` | no |
| <a name="input_persistence_size"></a> [persistence\_size](#input\_persistence\_size) | Size of the SonarQube data volume. | `string` | `"20Gi"` | no |
| <a name="input_pod_labels"></a> [pod\_labels](#input\_pod\_labels) | Extra labels applied to the SonarQube pods. | `map(string)` | <pre>{<br/>  "app.kubernetes.io/part-of": "code-quality-platform"<br/>}</pre> | no |
| <a name="input_project"></a> [project](#input\_project) | Short project identifier used to build resource names and tags. | `string` | n/a | yes |
| <a name="input_service_type"></a> [service\_type](#input\_service\_type) | Kubernetes Service type for SonarQube. ClusterIP keeps the app internal and is fronted by an Ingress. | `string` | `"ClusterIP"` | no |
| <a name="input_set_default_storage_class"></a> [set\_default\_storage\_class](#input\_set\_default\_storage\_class) | Mark the created gp3 StorageClass as the cluster default. | `bool` | `true` | no |
| <a name="input_sonar_properties"></a> [sonar\_properties](#input\_sonar\_properties) | Additional sonar.properties entries passed to the chart (for example sonar.forceAuthentication). | `map(string)` | `{}` | no |
| <a name="input_state_bucket_name"></a> [state\_bucket\_name](#input\_state\_bucket\_name) | S3 bucket that holds the Terraform state for every root module in this environment. | `string` | n/a | yes |
| <a name="input_state_key_prefix"></a> [state\_key\_prefix](#input\_state\_key\_prefix) | First path segment of the Terraform state keys, e.g. environments. | `string` | `"environments"` | no |
| <a name="input_storage_class_name"></a> [storage\_class\_name](#input\_storage\_class\_name) | StorageClass created for SonarQube's persistent volume (EBS gp3). | `string` | `"ebs-gp3"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged into the default tag set applied to every AWS resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_admin_secret_name"></a> [admin\_secret\_name](#output\_admin\_secret\_name) | Kubernetes secret that holds the admin password, passcode and encryption key. |
| <a name="output_chart_version"></a> [chart\_version](#output\_chart\_version) | Pinned SonarSource chart version that was deployed. |
| <a name="output_database_endpoint"></a> [database\_endpoint](#output\_database\_endpoint) | Private RDS endpoint SonarQube connects to. |
| <a name="output_database_secret_name"></a> [database\_secret\_name](#output\_database\_secret\_name) | Kubernetes secret that holds the JDBC credentials. |
| <a name="output_ingress_host"></a> [ingress\_host](#output\_ingress\_host) | Hostname published in the Ingress rule (null when ingress is disabled). |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Kubernetes namespace that hosts SonarQube. |
| <a name="output_release_name"></a> [release\_name](#output\_release\_name) | Name of the Helm release. |
| <a name="output_release_version"></a> [release\_version](#output\_release\_version) | Revision of the deployed Helm release. |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | In-cluster Kubernetes Service that fronts SonarQube. The chart names it <release>-<chart>, so the default is sonarqube-sonarqube. |
| <a name="output_status"></a> [status](#output\_status) | Status of the Helm release as reported by the Helm provider. |
| <a name="output_storage_class_name"></a> [storage\_class\_name](#output\_storage\_class\_name) | StorageClass used for the SonarQube data volume. |
<!-- END_TF_DOCS -->
