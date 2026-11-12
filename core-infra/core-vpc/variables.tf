variable "project" {
  description = "Short project identifier used to build resource names and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project))
    error_message = "project must be 3-21 characters, lowercase alphanumeric or hyphens, and start with a letter."
  }
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region that hosts the VPC."
  type        = string
  default     = "eu-west-1"

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS region name, e.g. eu-west-1."
  }
}

variable "state_bucket_name" {
  description = "S3 bucket that holds the Terraform state for every root module in this environment."
  type        = string
}

variable "state_key_prefix" {
  description = "First path segment of the Terraform state keys, e.g. environments."
  type        = string
  default     = "environments"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC. Must be large enough for three tiers across at least two AZs."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "azs" {
  description = "Availability zones used for the VPC. At least two are required for high availability."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2
    error_message = "At least two availability zones are required."
  }
}

variable "public_subnets" {
  description = "Public subnet CIDRs. Only internet-facing load balancers and NAT gateways live here."
  type        = list(string)

  validation {
    condition     = length(var.public_subnets) == length(var.azs)
    error_message = "public_subnets must contain exactly one CIDR per availability zone."
  }
}

variable "private_subnets" {
  description = "Private application subnet CIDRs that host EKS nodes and egress via NAT gateways."
  type        = list(string)

  validation {
    condition     = length(var.private_subnets) == length(var.azs)
    error_message = "private_subnets must contain exactly one CIDR per availability zone."
  }
}

variable "database_subnets" {
  description = "Isolated database subnet CIDRs. These have no route to an internet or NAT gateway."
  type        = list(string)

  validation {
    condition     = length(var.database_subnets) == length(var.azs)
    error_message = "database_subnets must contain exactly one CIDR per availability zone."
  }
}

variable "enable_nat_gateway" {
  description = "Create NAT gateways so private subnets can reach the internet for patching and image pulls."
  type        = bool
  default     = true
}

variable "one_nat_gateway_per_az" {
  description = "Deploy one NAT gateway per AZ (true) or share a single NAT gateway (false, dev only)."
  type        = bool
  default     = true
}

variable "create_vpc_endpoints" {
  description = "Create gateway and interface VPC endpoints so private workloads do not need NAT for AWS APIs."
  type        = bool
  default     = true
}

variable "vpc_interface_endpoint_services" {
  description = "AWS services (short names) that receive an interface endpoint in the private subnets."
  type        = list(string)
  default = [
    "ec2",
    "ec2messages",
    "ecr.api",
    "ecr.dkr",
    "elasticloadbalancing",
    "kms",
    "logs",
    "monitoring",
    "secretsmanager",
    "ssm",
    "ssmmessages",
    "sts",
  ]

  validation {
    condition     = length(var.vpc_interface_endpoint_services) > 0
    error_message = "vpc_interface_endpoint_services must contain at least one service name."
  }
}

variable "flow_log_retention_in_days" {
  description = "Retention period for VPC flow logs in CloudWatch Logs."
  type        = number
  default     = 365

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flow_log_retention_in_days)
    error_message = "flow_log_retention_in_days must be a retention value supported by CloudWatch Logs."
  }
}

variable "flow_log_kms_deletion_window_in_days" {
  description = "Waiting period before the flow log KMS key is destroyed after scheduling deletion."
  type        = number
  default     = 30

  validation {
    condition     = var.flow_log_kms_deletion_window_in_days >= 7 && var.flow_log_kms_deletion_window_in_days <= 30
    error_message = "flow_log_kms_deletion_window_in_days must be between 7 and 30."
  }
}

variable "tags" {
  description = "Additional tags merged into the default tag set applied to every resource."
  type        = map(string)
  default     = {}
}
