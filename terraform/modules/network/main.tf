terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Needed to build the S3 gateway endpoint's service name, which is
# region-qualified (com.amazonaws.<region>.s3).
data "aws_region" "current" {}

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  # DNS hostnames must be on for instances to resolve the private DNS names
  # that VPC endpoints publish. Off by default on non-default VPCs.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-igw" })
}

# A subnet is "public" only because its route table points 0.0.0.0/0 at the
# IGW — nothing about the subnet resource itself makes it public.
resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  # Left off deliberately: whether an instance gets a public IP is decided
  # per-instance (associate_public_ip_address), not per-subnet. The bastion
  # opts in; nothing else should.
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name}-${each.key}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = merge(var.tags, {
    Name = "${var.name}-${each.key}"
    Tier = "private"
  })
}

# ---------------------------------------------------------------------------
# Outbound path for the private subnets
#
# One NAT Gateway, not one per AZ. A NAT Gateway is ~$32/month plus data
# processing, and this is a demo stack. The trade-off is real: if the AZ
# holding this NAT goes down, the private subnet in the *other* AZ loses
# outbound internet. For production, create one per AZ and point each private
# route table at the NAT in its own AZ.
# ---------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  domain = "vpc"

  tags = merge(var.tags, { Name = "${var.name}-nat-eip" })
}

resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[var.nat_gateway_subnet_key].id

  # A NAT Gateway in a subnet with no IGW route is created successfully but
  # silently routes nowhere. Force the IGW to exist first.
  depends_on = [aws_internet_gateway.this]

  tags = merge(var.tags, { Name = "${var.name}-nat" })
}

# ---------------------------------------------------------------------------
# Route tables
# ---------------------------------------------------------------------------

# All public subnets share one route table — they all want the same thing.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-public-rt" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# One route table per private subnet, even though they currently hold
# identical routes. This is what makes moving to per-AZ NAT Gateways a
# one-line change instead of a re-plumb.
resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-${each.key}-rt" })
}

resource "aws_route" "private_nat" {
  for_each = var.enable_nat_gateway ? aws_subnet.private : {}

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# ---------------------------------------------------------------------------
# S3 Gateway Endpoint
#
# Free, and it keeps instance->S3 traffic off the NAT Gateway entirely (NAT
# charges ~$0.045/GB processed; the endpoint charges nothing). It works by
# injecting a prefix-list route into the route tables listed below, so S3
# traffic never leaves the AWS network.
# ---------------------------------------------------------------------------
resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_gateway_endpoint ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [for rt in aws_route_table.private : rt.id],
    [aws_route_table.public.id],
  )

  tags = merge(var.tags, { Name = "${var.name}-s3-endpoint" })
}
