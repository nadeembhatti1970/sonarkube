# ---------------------------------------------------------------------------
# Network placement and access control for the database.
#
# The instance lives in the isolated database subnets created by core-vpc and
# accepts TCP 5432 only from security groups referenced in the database-clients
# group (attached to the EKS managed node groups). There is no CIDR rule, no
# public endpoint and no egress rule.
# ---------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-postgres"
  description = "PostgreSQL access control for ${local.db_identifier}"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-rds-postgres" })
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_clients" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL from workloads carrying the database-clients security group"
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
  referenced_security_group_id = data.terraform_remote_state.vpc.outputs.database_client_security_group_id
}

# NOTE: no egress rules on purpose. RDS responses are stateful and the instance
# never initiates outbound connections, so the group denies all egress.
