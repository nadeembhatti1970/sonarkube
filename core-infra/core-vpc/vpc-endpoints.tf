# ---------------------------------------------------------------------------
# VPC endpoints.
#
# Private workloads (EKS nodes, SonarQube pods) must pull container images,
# read Secrets Manager values and ship logs without a route to the internet.
# Gateway endpoint for S3 also removes NAT data-processing charges for image
# layers stored in ECR's S3 backend.
#
# The database route table is intentionally excluded: the database tier keeps
# no route other than the local VPC route.
# ---------------------------------------------------------------------------
locals {
  create_endpoints = var.create_vpc_endpoints

  interface_endpoint_services = toset(var.vpc_interface_endpoint_services)
}

resource "aws_security_group" "vpc_endpoints" {
  count = local.create_endpoints ? 1 : 0

  name        = "${local.name_prefix}-vpc-endpoints"
  description = "Allow HTTPS from inside the VPC to the interface VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpc-endpoints" })
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_https" {
  count = local.create_endpoints ? 1 : 0

  security_group_id = aws_security_group.vpc_endpoints[0].id
  description       = "HTTPS from the VPC CIDR to the interface endpoints"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_security_group_egress_rule" "vpc_endpoints_all" {
  count = local.create_endpoints ? 1 : 0

  security_group_id = aws_security_group.vpc_endpoints[0].id
  description       = "Endpoint ENIs answer on the same connection; egress is required by the AWS control plane"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_endpoint" "s3" {
  count = local.create_endpoints ? 1 : 0

  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = concat(
    module.vpc.private_route_table_ids,
    module.vpc.public_route_table_ids,
  )

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-s3-gateway-endpoint" })
}

resource "aws_vpc_endpoint" "dynamodb" {
  count = local.create_endpoints ? 1 : 0

  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-dynamodb-gateway-endpoint" })
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.create_endpoints ? local.interface_endpoint_services : toset([])

  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${replace(each.value, ".", "-")}-endpoint"
  })
}
