# core-vpc

Three-tier VPC built on `terraform-aws-modules/vpc/aws` (6.7.3), with flow logs,
VPC endpoints and the shared database-clients security group.

## Layout

| Tier | CIDR (/16 base) | Contents | Internet path |
| :--- | :--- | :--- | :--- |
| public | `10.20.0.0/20` x3 | ALB, NAT gateways, IGW | direct |
| private | `10.20.48.0/20` x3 | EKS managed node groups | NAT gateway per AZ |
| database | `10.20.96.0/24` x3 | RDS PostgreSQL | **none** (dedicated route table, no IGW/NAT route) |

## What it creates

* VPC with DNS support/hostnames, one NAT gateway per AZ, and no auto-assigned
  public IPs.
* Default security group emptied, default network ACL restricted to the VPC CIDR.
* VPC flow logs (ALL traffic, 60s aggregation, custom forensic format) to a
  KMS-encrypted CloudWatch log group with 365 day retention.
* Gateway endpoints for S3 and DynamoDB, and interface endpoints for ECR, STS,
  Secrets Manager, KMS, CloudWatch, SSM, EC2 and ELB in the private subnets.
* RDS DB subnet group (`<project>-<env>-db`) created by the module.
* `database-clients` security group: created here, attached to EKS nodes in
  `core-eks`, referenced by the RDS ingress rule in `core-rds`. This breaks the
  RDS ↔ EKS dependency cycle without opening a CIDR.

## Usage, validation and tests

This is the first layer of the stack and has no upstream module state.

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
checkov -d core-infra/core-vpc

# 6. Apply the reviewed plan
terraform apply tfplan
# or, without a saved plan:
terraform apply -var-file=dev.tfvars
```

The repository-level wrappers run the same gates across all modules:

```bash
./scripts/validate.sh                        # fmt, validate, secret hygiene, checkov and tests
./scripts/plan-guard.sh core-infra/core-vpc               # plan JSON, Checkov terraform_plan and destroy gate
```

`plan-guard.sh` needs AWS credentials and state access; `terraform test` does not.

## Key inputs

| Name | Description | Default |
| :--- | :--- | :--- |
| `vpc_cidr` | VPC CIDR | `10.20.0.0/16` |
| `azs` | AZ list (>= 2, one subnet per AZ) | required |
| `public_subnets`, `private_subnets`, `database_subnets` | Tier CIDRs | required |
| `enable_nat_gateway` | Create NAT gateways | `true` |
| `one_nat_gateway_per_az` | One NAT per AZ | `true` |
| `create_vpc_endpoints` | Create endpoint set | `true` |
| `vpc_interface_endpoint_services` | Interface endpoint services | ECR/STS/KMS/etc. |
| `flow_log_retention_in_days` | Flow log retention | `365` |

## Outputs

`vpc_id`, `vpc_cidr`, `availability_zones`, `public_subnet_ids`,
`private_subnet_ids`, `database_subnet_ids`, `database_subnet_group_name`,
`database_client_security_group_id`, `vpc_endpoint_security_group_id`,
`flow_log_destination_arn`, `default_security_group_id`.

## Notes

* Disabling `create_vpc_endpoints` saves per-endpoint hourly cost but forces all
  AWS API traffic through NAT.
* `one_nat_gateway_per_az = false` is a dev-only cost saving; it removes AZ
  independence for egress.
* The database subnets are deliberately absent from the S3 gateway endpoint
  route tables so the isolation guarantee is not weakened.

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

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | 6.7.3 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_kms_alias.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_security_group.database_clients](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.vpc_endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_endpoint.dynamodb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.interface](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_security_group_egress_rule.vpc_endpoints_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.vpc_endpoints_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region that hosts the VPC. | `string` | `"eu-west-1"` | no |
| <a name="input_azs"></a> [azs](#input\_azs) | Availability zones used for the VPC. At least two are required for high availability. | `list(string)` | n/a | yes |
| <a name="input_create_vpc_endpoints"></a> [create\_vpc\_endpoints](#input\_create\_vpc\_endpoints) | Create gateway and interface VPC endpoints so private workloads do not need NAT for AWS APIs. | `bool` | `true` | no |
| <a name="input_database_subnets"></a> [database\_subnets](#input\_database\_subnets) | Isolated database subnet CIDRs. These have no route to an internet or NAT gateway. | `list(string)` | n/a | yes |
| <a name="input_enable_nat_gateway"></a> [enable\_nat\_gateway](#input\_enable\_nat\_gateway) | Create NAT gateways so private subnets can reach the internet for patching and image pulls. | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (dev, staging, prod). | `string` | n/a | yes |
| <a name="input_flow_log_kms_deletion_window_in_days"></a> [flow\_log\_kms\_deletion\_window\_in\_days](#input\_flow\_log\_kms\_deletion\_window\_in\_days) | Waiting period before the flow log KMS key is destroyed after scheduling deletion. | `number` | `30` | no |
| <a name="input_flow_log_retention_in_days"></a> [flow\_log\_retention\_in\_days](#input\_flow\_log\_retention\_in\_days) | Retention period for VPC flow logs in CloudWatch Logs. | `number` | `365` | no |
| <a name="input_one_nat_gateway_per_az"></a> [one\_nat\_gateway\_per\_az](#input\_one\_nat\_gateway\_per\_az) | Deploy one NAT gateway per AZ (true) or share a single NAT gateway (false, dev only). | `bool` | `true` | no |
| <a name="input_private_subnets"></a> [private\_subnets](#input\_private\_subnets) | Private application subnet CIDRs that host EKS nodes and egress via NAT gateways. | `list(string)` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | Short project identifier used to build resource names and tags. | `string` | n/a | yes |
| <a name="input_public_subnets"></a> [public\_subnets](#input\_public\_subnets) | Public subnet CIDRs. Only internet-facing load balancers and NAT gateways live here. | `list(string)` | n/a | yes |
| <a name="input_state_bucket_name"></a> [state\_bucket\_name](#input\_state\_bucket\_name) | S3 bucket that holds the Terraform state for every root module in this environment. | `string` | n/a | yes |
| <a name="input_state_key_prefix"></a> [state\_key\_prefix](#input\_state\_key\_prefix) | First path segment of the Terraform state keys, e.g. environments. | `string` | `"environments"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged into the default tag set applied to every resource. | `map(string)` | `{}` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | IPv4 CIDR block for the VPC. Must be large enough for three tiers across at least two AZs. | `string` | `"10.20.0.0/16"` | no |
| <a name="input_vpc_interface_endpoint_services"></a> [vpc\_interface\_endpoint\_services](#input\_vpc\_interface\_endpoint\_services) | AWS services (short names) that receive an interface endpoint in the private subnets. | `list(string)` | <pre>[<br/>  "ec2",<br/>  "ec2messages",<br/>  "ecr.api",<br/>  "ecr.dkr",<br/>  "elasticloadbalancing",<br/>  "kms",<br/>  "logs",<br/>  "monitoring",<br/>  "secretsmanager",<br/>  "ssm",<br/>  "ssmmessages",<br/>  "sts"<br/>]</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_availability_zones"></a> [availability\_zones](#output\_availability\_zones) | Availability zones the VPC spans. |
| <a name="output_database_client_security_group_id"></a> [database\_client\_security\_group\_id](#output\_database\_client\_security\_group\_id) | Security group attached to workloads that may reach the database tier. |
| <a name="output_database_route_table_ids"></a> [database\_route\_table\_ids](#output\_database\_route\_table\_ids) | Route table IDs for the isolated database subnets (no internet route). |
| <a name="output_database_subnet_group_name"></a> [database\_subnet\_group\_name](#output\_database\_subnet\_group\_name) | Name of the RDS DB subnet group created by the VPC module. |
| <a name="output_database_subnet_ids"></a> [database\_subnet\_ids](#output\_database\_subnet\_ids) | Isolated database subnet IDs (RDS). |
| <a name="output_default_security_group_id"></a> [default\_security\_group\_id](#output\_default\_security\_group\_id) | ID of the VPC default security group (all traffic denied). |
| <a name="output_flow_log_destination_arn"></a> [flow\_log\_destination\_arn](#output\_flow\_log\_destination\_arn) | CloudWatch log group ARN that receives VPC flow logs. |
| <a name="output_flow_log_id"></a> [flow\_log\_id](#output\_flow\_log\_id) | ID of the VPC flow log. |
| <a name="output_nat_gateway_public_ips"></a> [nat\_gateway\_public\_ips](#output\_nat\_gateway\_public\_ips) | Elastic IPs of the NAT gateways (useful for third-party allow lists). |
| <a name="output_private_route_table_ids"></a> [private\_route\_table\_ids](#output\_private\_route\_table\_ids) | Route table IDs for the private subnets. |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | Private subnet IDs (EKS managed node groups). |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | Public subnet IDs (load balancers, NAT gateways). |
| <a name="output_vpc_arn"></a> [vpc\_arn](#output\_vpc\_arn) | ARN of the VPC. |
| <a name="output_vpc_cidr"></a> [vpc\_cidr](#output\_vpc\_cidr) | IPv4 CIDR block of the VPC. |
| <a name="output_vpc_endpoint_security_group_id"></a> [vpc\_endpoint\_security\_group\_id](#output\_vpc\_endpoint\_security\_group\_id) | Security group protecting the interface VPC endpoints (null when endpoints are disabled). |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC. |
<!-- END_TF_DOCS -->
