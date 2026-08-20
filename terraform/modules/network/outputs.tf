output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Map of public subnet key -> subnet ID."
  value       = { for k, s in aws_subnet.public : k => s.id }
}

output "private_subnet_ids" {
  description = "Map of private subnet key -> subnet ID."
  value       = { for k, s in aws_subnet.private : k => s.id }
}

output "public_subnet_azs" {
  description = "Map of public subnet key -> availability zone."
  value       = { for k, s in aws_subnet.public : k => s.availability_zone }
}

output "private_subnet_azs" {
  description = "Map of private subnet key -> availability zone."
  value       = { for k, s in aws_subnet.private : k => s.availability_zone }
}

output "internet_gateway_id" {
  description = "ID of the internet gateway."
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_id" {
  description = "ID of the NAT gateway, or null if disabled."
  value       = try(aws_nat_gateway.this[0].id, null)
}

output "nat_gateway_public_ip" {
  description = "Elastic IP of the NAT gateway — this is the source IP private instances appear as on the internet."
  value       = try(aws_eip.nat[0].public_ip, null)
}

output "public_route_table_id" {
  description = "ID of the shared public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Map of private subnet key -> route table ID."
  value       = { for k, rt in aws_route_table.private : k => rt.id }
}

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 gateway endpoint, or null if disabled."
  value       = try(aws_vpc_endpoint.s3[0].id, null)
}
