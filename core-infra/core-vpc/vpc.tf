# ---------------------------------------------------------------------------
# Three-tier VPC built on the community terraform-aws-vpc module.
#
#   public subnets   -> internet-facing load balancers, NAT gateways
#   private subnets  -> EKS managed node groups (egress through NAT gateways)
#   database subnets -> RDS PostgreSQL, isolated route table with no default
#                       route, no NAT attachment, no public IPs
#
# The database tier is deliberately never referenced by
# create_database_nat_gateway_route or create_database_internet_gateway_route,
# which is what guarantees "no path to the internet" rather than relying on
# security groups alone.
# ---------------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.3"

  name = "${local.name_prefix}-vpc"
  cidr = var.vpc_cidr

  azs              = var.azs
  public_subnets   = var.public_subnets
  private_subnets  = var.private_subnets
  database_subnets = var.database_subnets

  create_database_subnet_group           = true
  database_subnet_group_name             = "${local.name_prefix}-db"
  create_database_subnet_route_table     = true
  create_database_internet_gateway_route = false
  create_database_nat_gateway_route      = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway     = var.enable_nat_gateway
  one_nat_gateway_per_az = var.enable_nat_gateway ? var.one_nat_gateway_per_az : false
  single_nat_gateway     = false

  # Never auto-assign public IPs: workloads must opt in explicitly.
  map_public_ip_on_launch = false

  # Replace the permissive default security group with an empty one.
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  # Replace the allow-all default network ACL with a VPC-internal-only ACL.
  manage_default_network_acl = true
  default_network_acl_name   = "${local.name_prefix}-default-nacl"
  default_network_acl_ingress = [
    {
      protocol   = "-1"
      rule_no    = 100
      action     = "allow"
      cidr_block = var.vpc_cidr
      from_port  = 0
      to_port    = 0
    },
    {
      protocol   = "-1"
      rule_no    = 32766
      action     = "deny"
      cidr_block = "0.0.0.0/0"
      from_port  = 0
      to_port    = 0
    }
  ]
  default_network_acl_egress = [
    {
      protocol   = "-1"
      rule_no    = 100
      action     = "allow"
      cidr_block = var.vpc_cidr
      from_port  = 0
      to_port    = 0
    },
    {
      protocol   = "-1"
      rule_no    = 32766
      action     = "deny"
      cidr_block = "0.0.0.0/0"
      from_port  = 0
      to_port    = 0
    }
  ]

  # Flow logs for every ENI in the VPC, encrypted with a dedicated CMK.
  enable_flow_log                                 = true
  flow_log_destination_type                       = "cloud-watch-logs"
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_cloudwatch_log_group_name_prefix       = "/aws/vpc/${local.name_prefix}"
  flow_log_cloudwatch_log_group_retention_in_days = var.flow_log_retention_in_days
  flow_log_cloudwatch_log_group_kms_key_id        = aws_kms_key.flow_logs.arn
  flow_log_traffic_type                           = "ALL"
  flow_log_max_aggregation_interval               = 60
  flow_log_log_format = join(" ", [
    "$${version}",
    "$${account-id}",
    "$${interface-id}",
    "$${srcaddr}",
    "$${dstaddr}",
    "$${srcport}",
    "$${dstport}",
    "$${protocol}",
    "$${packets}",
    "$${bytes}",
    "$${start}",
    "$${end}",
    "$${action}",
    "$${log-status}",
    "$${vpc-id}",
    "$${subnet-id}",
    "$${instance-id}",
    "$${tcp-flags}",
    "$${type}",
    "$${pkt-srcaddr}",
    "$${pkt-dstaddr}",
    "$${flow-direction}",
    "$${traffic-path}",
  ])

  tags = local.common_tags

  vpc_tags = {
    Name = "${local.name_prefix}-vpc"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb"                     = "1"
    "kubernetes.io/cluster/${local.name_prefix}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"            = "1"
    "kubernetes.io/cluster/${local.name_prefix}" = "shared"
  }

  database_subnet_tags = {
    Tier = "database"
  }

  database_subnet_group_tags = {
    Name = "${local.name_prefix}-db"
  }

  nat_gateway_tags = {
    Name = "${local.name_prefix}-nat"
  }

  nat_eip_tags = {
    Name = "${local.name_prefix}-nat-eip"
  }

  igw_tags = {
    Name = "${local.name_prefix}-igw"
  }

  vpc_flow_log_tags = {
    Name = "${local.name_prefix}-vpc-flow-logs"
  }
}
