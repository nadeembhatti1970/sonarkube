output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "IPv4 CIDR block of the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "vpc_arn" {
  description = "ARN of the VPC."
  value       = module.vpc.vpc_arn
}

output "availability_zones" {
  description = "Availability zones the VPC spans."
  value       = module.vpc.azs
}

output "public_subnet_ids" {
  description = "Public subnet IDs (load balancers, NAT gateways)."
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "Private subnet IDs (EKS managed node groups)."
  value       = module.vpc.private_subnets
}

output "database_subnet_ids" {
  description = "Isolated database subnet IDs (RDS)."
  value       = module.vpc.database_subnets
}

output "database_subnet_group_name" {
  description = "Name of the RDS DB subnet group created by the VPC module."
  value       = module.vpc.database_subnet_group_name
}

output "private_route_table_ids" {
  description = "Route table IDs for the private subnets."
  value       = module.vpc.private_route_table_ids
}

output "database_route_table_ids" {
  description = "Route table IDs for the isolated database subnets (no internet route)."
  value       = module.vpc.database_route_table_ids
}

output "nat_gateway_public_ips" {
  description = "Elastic IPs of the NAT gateways (useful for third-party allow lists)."
  value       = module.vpc.nat_public_ips
}

output "database_client_security_group_id" {
  description = "Security group attached to workloads that may reach the database tier."
  value       = aws_security_group.database_clients.id
}

output "vpc_endpoint_security_group_id" {
  description = "Security group protecting the interface VPC endpoints (null when endpoints are disabled)."
  value       = try(aws_security_group.vpc_endpoints[0].id, null)
}

output "flow_log_id" {
  description = "ID of the VPC flow log."
  value       = module.vpc.vpc_flow_log_id
}

output "flow_log_destination_arn" {
  description = "CloudWatch log group ARN that receives VPC flow logs."
  value       = module.vpc.vpc_flow_log_destination_arn
}

output "default_security_group_id" {
  description = "ID of the VPC default security group (all traffic denied)."
  value       = module.vpc.default_security_group_id
}
