terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_ami" "al2023" {
  count = var.ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id = coalesce(var.ami_id, try(data.aws_ami.al2023[0].id, null))
}

# name_prefix, not name. Security group names must be unique within a VPC, and
# create_before_destroy means the replacement exists alongside the original
# for a moment — a fixed name would make every replacement fail with
# InvalidGroup.Duplicate. AWS appends a unique suffix; the readable identity
# lives in the Name tag.
#
# The replacement chain works because attaching a different security group to
# a running instance is an in-place update: create new SG -> update the
# instance's vpc_security_group_ids -> destroy the old SG.
resource "aws_security_group" "this" {
  name_prefix = "${var.name}-sg-"
  description = "Security group for ${var.name}"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = toset(var.allowed_ssh_cidrs)

  security_group_id = aws_security_group.this.id
  description       = "SSH from ${each.value}"
  cidr_ipv4         = each.value
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

# Rules from `ingress_rules`, which unlike allowed_ssh_cidrs can point at a
# source security group rather than a CIDR.
resource "aws_vpc_security_group_ingress_rule" "extra" {
  for_each = var.ingress_rules

  security_group_id            = aws_security_group.this.id
  description                  = coalesce(each.value.description, each.key)
  cidr_ipv4                    = each.value.cidr_ipv4
  referenced_security_group_id = each.value.source_security_group_id
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  ip_protocol                  = each.value.ip_protocol
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "Allow all outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "this" {
  ami           = local.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = var.key_name

  iam_instance_profile        = var.iam_instance_profile
  user_data                   = var.user_data
  user_data_replace_on_change = var.user_data_replace_on_change

  vpc_security_group_ids      = [aws_security_group.this.id]
  associate_public_ip_address = var.associate_public_ip

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  # Require IMDSv2 — blocks the SSRF-to-credentials path that IMDSv1 allows.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(var.tags, { Name = var.name })
}
