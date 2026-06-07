###############################################################################
# VPC module - outputs (consumed by the control-plane / worker-pool modules)
###############################################################################

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs (ingress LB, NAT)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs (K8s nodes / worker ASG)"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ids" {
  description = "List of NAT gateway IDs (empty when NAT is disabled)"
  value       = aws_nat_gateway.this[*].id
}

output "private_route_table_ids" {
  description = "Private route table IDs. When NAT is disabled, the control-plane module adds the default route to these."
  value       = aws_route_table.private[*].id
}

output "availability_zones" {
  description = "AZs the subnets are spread across"
  value       = var.azs
}
