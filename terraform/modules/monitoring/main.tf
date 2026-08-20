terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  log_group_name = coalesce(var.log_group_name, "/aws/ec2/${var.name}")

  # An alarm with no action is a dashboard decoration. If no topic exists,
  # leave the action lists empty rather than pointing at nothing.
  alarm_actions = var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : var.alarm_action_arns
}

# ---------------------------------------------------------------------------
# Log destination
#
# Created here rather than left to the CloudWatch agent. The agent will create
# a log group implicitly on first write, but with Never Expire retention —
# which is how log bills quietly grow.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "app" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, { Name = local.log_group_name })
}

# ---------------------------------------------------------------------------
# Alarm notification
# ---------------------------------------------------------------------------
resource "aws_sns_topic" "alarms" {
  count = var.create_sns_topic ? 1 : 0

  name = "${var.name}-alarms"

  tags = merge(var.tags, { Name = "${var.name}-alarms" })
}

# Email subscriptions land in "pending confirmation" until someone clicks the
# link in the confirmation mail. Terraform reports success either way.
resource "aws_sns_topic_subscription" "email" {
  count = var.create_sns_topic && var.alarm_email != null ? 1 : 0

  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ---------------------------------------------------------------------------
# Per-instance alarms
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  for_each = var.instance_ids

  alarm_name          = "${var.name}-${each.key}-cpu-high"
  alarm_description   = "CPU on ${each.key} above ${var.cpu_threshold}% for ${var.evaluation_periods} periods"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = var.alarm_period
  evaluation_periods  = var.evaluation_periods
  threshold           = var.cpu_threshold
  comparison_operator = "GreaterThanThreshold"

  dimensions = { InstanceId = each.value }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  # Basic EC2 monitoring publishes every 5 minutes. If period is shorter than
  # that most datapoints are simply missing, so do not alarm on the gaps.
  treat_missing_data = "notBreaching"

  tags = merge(var.tags, { Name = "${var.name}-${each.key}-cpu-high" })
}

# StatusCheckFailed covers both the instance check (OS-level: kernel panic,
# exhausted memory, bad network config) and the system check (AWS-level:
# host hardware, network reachability).
resource "aws_cloudwatch_metric_alarm" "status_check" {
  for_each = var.instance_ids

  alarm_name          = "${var.name}-${each.key}-status-check"
  alarm_description   = "EC2 status check failing on ${each.key}"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"

  dimensions = { InstanceId = each.value }

  alarm_actions      = local.alarm_actions
  ok_actions         = local.alarm_actions
  treat_missing_data = "breaching"

  tags = merge(var.tags, { Name = "${var.name}-${each.key}-status-check" })
}

# ---------------------------------------------------------------------------
# Load balancer alarms
#
# These are the ones that actually tell you the site is down. A single
# unhealthy host is survivable; zero healthy hosts is an outage.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  count = var.alb_arn_suffix == null || var.target_group_arn_suffix == null ? 0 : 1

  alarm_name          = "${var.name}-alb-unhealthy-hosts"
  alarm_description   = "At least one target is failing ALB health checks"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  alarm_actions      = local.alarm_actions
  ok_actions         = local.alarm_actions
  treat_missing_data = "notBreaching"

  tags = merge(var.tags, { Name = "${var.name}-alb-unhealthy-hosts" })
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  count = var.alb_arn_suffix == null ? 0 : 1

  alarm_name          = "${var.name}-alb-5xx"
  alarm_description   = "Load balancer returned 5xx responses of its own — usually no healthy targets"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.alb_5xx_threshold
  comparison_operator = "GreaterThanThreshold"

  dimensions = { LoadBalancer = var.alb_arn_suffix }

  alarm_actions      = local.alarm_actions
  ok_actions         = local.alarm_actions
  treat_missing_data = "notBreaching"

  tags = merge(var.tags, { Name = "${var.name}-alb-5xx" })
}
