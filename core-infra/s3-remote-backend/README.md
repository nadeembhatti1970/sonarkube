# s3-remote-backend

Bootstrap module that creates the S3 bucket every other root module uses as its
Terraform backend, plus a dedicated access-log bucket and a customer managed
KMS key.

## Why local state

This module creates the bucket it would otherwise depend on, so it runs with
local state once per account/environment. Store the resulting
`terraform.tfstate` in your secrets manager or an offline secure store; it
contains only bucket names, ARNs and key IDs.

## What it creates

| Resource | Purpose |
| :--- | :--- |
| `aws_s3_bucket.tfstate` | State storage: versioning, SSE-KMS, public access block, TLS-only policy, non-current version expiry |
| `aws_s3_bucket.state_access_logs` | Server access log destination (365 day retention, own lifecycle) |
| `aws_kms_key.tfstate` | CMK for state and log objects, annual rotation, 30 day deletion window |
| `aws_s3_bucket_policy.tfstate` | Denies plaintext transport and unencrypted `PutObject` |

DynamoDB locking is intentionally absent: every `dev.tfbackend` uses native S3
locking (`use_lockfile = true`, Terraform >= 1.10).

## Usage, validation and tests

Run this module **once per account/environment before any other module**. It uses local state by design, so there is no `dev.tfbackend`; `dev.tfvars` still holds the environment inputs. Archive the resulting `terraform.tfstate` in your secure store.

Run these commands from this module directory. Environment inputs come from `dev.tfvars`.

```bash
# 1. Initialise local state (the bootstrap module cannot use the backend it creates)
terraform init

# 2. Check formatting and configuration
terraform fmt -check -recursive .
terraform validate

# 3. Plan with the environment inputs
#    (requires AWS credentials)
terraform plan -var-file=dev.tfvars -out=tfplan

# 4. Run the native tests (mocked providers, no AWS calls)
terraform test -test-directory=testing

# 5. Static analysis: run from the repository root so .checkov.yaml applies
#    (from this module directory: cd ../.. first)
checkov -d core-infra/s3-remote-backend

# 6. Apply the reviewed plan
terraform apply tfplan
# or, without a saved plan:
terraform apply -var-file=dev.tfvars
```

The state bucket names are globally unique; adjust `dev.tfvars` if they are already taken.

The repository-level wrappers run the same gates across all modules:

```bash
./scripts/validate.sh                        # fmt, validate, secret hygiene, checkov and tests
./scripts/plan-guard.sh core-infra/s3-remote-backend               # plan JSON, Checkov terraform_plan and destroy gate
```

`plan-guard.sh` needs AWS credentials and state access; `terraform test` does not.

## Key inputs

| Name | Description | Default |
| :--- | :--- | :--- |
| `state_bucket_name` | Globally unique state bucket name | required |
| `state_access_logs_bucket_name` | Access log bucket name | required |
| `kms_deletion_window_in_days` | CMK deletion window | `30` |
| `noncurrent_version_expiration_days` | Retention for old state versions | `90` |

## Outputs

| Name | Description |
| :--- | :--- |
| `state_bucket_name` | Bucket for `dev.tfbackend` |
| `kms_key_alias` | Alias for `kms_key_id` in `dev.tfbackend` |
| `backend_configuration` | Map of values to paste into every `dev.tfbackend` |

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

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_kms_alias.tfstate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.tfstate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_bucket.state_access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.tfstate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.state_access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.tfstate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.tfstate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_ownership_controls.state_access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_ownership_controls.tfstate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.state_access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_policy.tfstate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.state_access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.tfstate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.state_access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.tfstate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.state_access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_bucket_versioning.tfstate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region that hosts the Terraform state bucket and every workload resource. | `string` | `"eu-west-1"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (dev, staging, prod). | `string` | n/a | yes |
| <a name="input_kms_deletion_window_in_days"></a> [kms\_deletion\_window\_in\_days](#input\_kms\_deletion\_window\_in\_days) | Waiting period, in days, before the state bucket KMS key is destroyed after scheduling deletion. | `number` | `30` | no |
| <a name="input_noncurrent_version_expiration_days"></a> [noncurrent\_version\_expiration\_days](#input\_noncurrent\_version\_expiration\_days) | Number of days after which non-current state object versions are permanently deleted. | `number` | `90` | no |
| <a name="input_project"></a> [project](#input\_project) | Short project identifier used to build resource names and tags. | `string` | n/a | yes |
| <a name="input_state_access_logs_bucket_name"></a> [state\_access\_logs\_bucket\_name](#input\_state\_access\_logs\_bucket\_name) | Name of the S3 bucket that receives server access logs for the state bucket. | `string` | n/a | yes |
| <a name="input_state_bucket_name"></a> [state\_bucket\_name](#input\_state\_bucket\_name) | Globally unique name of the S3 bucket that stores Terraform state for all root modules. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged into the default tag set applied to every resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_backend_configuration"></a> [backend\_configuration](#output\_backend\_configuration) | Values to place in each root module's dev.tfbackend file. |
| <a name="output_kms_key_alias"></a> [kms\_key\_alias](#output\_kms\_key\_alias) | Alias of the KMS key used to encrypt Terraform state (set as kms\_key\_id in dev.tfbackend). |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN of the KMS key used to encrypt Terraform state. |
| <a name="output_state_access_logs_bucket_name"></a> [state\_access\_logs\_bucket\_name](#output\_state\_access\_logs\_bucket\_name) | Name of the S3 bucket that receives server access logs for the state bucket. |
| <a name="output_state_bucket_arn"></a> [state\_bucket\_arn](#output\_state\_bucket\_arn) | ARN of the Terraform remote state bucket. |
| <a name="output_state_bucket_name"></a> [state\_bucket\_name](#output\_state\_bucket\_name) | Name of the S3 bucket that stores Terraform remote state. |
<!-- END_TF_DOCS -->
