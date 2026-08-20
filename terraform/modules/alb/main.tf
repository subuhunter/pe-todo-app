terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Security group
#
# This SG is the public front door. Everything behind it should accept traffic
# *from this security group ID*, never from a CIDR — that way the web tier
# stays reachable only through the load balancer no matter how its IPs change.
# ---------------------------------------------------------------------------
resource "aws_security_group" "this" {
  name_prefix = "${var.name}-alb-"
  description = "Security group for the ${var.name} application load balancer"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-alb-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "listener" {
  for_each = toset(var.ingress_cidrs)

  security_group_id = aws_security_group.this.id
  description       = "Listener traffic from ${each.value}"
  cidr_ipv4         = each.value
  from_port         = var.listener_port
  to_port           = var.listener_port
  ip_protocol       = "tcp"
}

# All-outbound rather than scoped to the target security groups. Scoping it
# would mean this module needs the web tier's SG ID while the web tier needs
# this module's SG ID — a module-level dependency cycle Terraform rejects.
# An ALB can only open connections to its registered targets regardless.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "Allow all outbound to targets"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------------------------------------------------------------------------
# Load balancer
# ---------------------------------------------------------------------------
resource "aws_lb" "this" {
  # ELB names are capped at 32 characters and reject most punctuation.
  name               = substr("${var.name}-alb", 0, 32)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.this.id]

  # An ALB requires at least two subnets in two different AZs. It places one
  # scaling set of nodes in each.
  subnets = var.subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  # Reject requests with malformed headers instead of forwarding them, which
  # closes off a class of request-smuggling tricks.
  drop_invalid_header_fields = true

  idle_timeout = var.idle_timeout

  dynamic "access_logs" {
    for_each = var.access_logs_bucket == null ? [] : [1]

    content {
      bucket  = var.access_logs_bucket
      prefix  = var.access_logs_prefix
      enabled = true
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-alb" })
}

# ---------------------------------------------------------------------------
# Target group
#
# Health checks are the whole point of this resource: a target that fails
# `unhealthy_threshold` consecutive checks stops receiving traffic, which is
# what turns two instances into an actual highly-available pair.
# ---------------------------------------------------------------------------
resource "aws_lb_target_group" "this" {
  # name_prefix, not name. Target group names must be unique, and
  # create_before_destroy below means the replacement has to exist alongside
  # the original for a moment. A fixed name would make every replacement fail
  # with DuplicateTargetGroupName. The prefix is capped at 6 characters by
  # AWS, so the readable identity lives in the Name tag instead.
  name_prefix = var.target_group_name_prefix

  port        = var.target_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  # How long to keep draining in-flight requests before removing a target.
  # 300s is the default and is painfully slow to watch during a demo.
  deregistration_delay = var.deregistration_delay

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = var.health_check_matcher
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
  }

  # A target group cannot be destroyed while a listener forwards to it, so the
  # replacement has to exist before the old one goes away.
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, { Name = "${var.name}-tg" })
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = merge(var.tags, { Name = "${var.name}-listener" })
}
