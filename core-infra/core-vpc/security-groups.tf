# ---------------------------------------------------------------------------
# Shared "database client" security group.
#
# This group is deliberately created in the network layer, not in the RDS or
# EKS layer, so that:
#
#   * RDS can reference it in its ingress rule (source = this SG) without
#     depending on the EKS module, and
#   * EKS node groups can attach it to their ENIs (vpc_security_group_ids)
#     without depending on the RDS module.
#
# Result: PostgreSQL 5432 is reachable only from workloads that carry this
# group. No CIDR based access, no NAT path, no public exposure.
# ---------------------------------------------------------------------------
resource "aws_security_group" "database_clients" {
  name        = "${local.name_prefix}-database-clients"
  description = "Workloads allowed to connect to the ${local.name_prefix} RDS PostgreSQL instance"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-database-clients" })
}
