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
# EC2 instance role
#
# The architecture diagram shows only an IAM *user*, but a user cannot be
# attached to an instance — an instance assumes a *role* through an instance
# profile and receives short-lived credentials from the metadata service.
# This is the piece that lets the web servers write to S3 and CloudWatch
# without any long-lived key material on disk.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "ec2" {
  name        = "${var.name}-ec2-role"
  description = "Role assumed by ${var.name} EC2 instances"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = merge(var.tags, { Name = "${var.name}-ec2-role" })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.name}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = merge(var.tags, { Name = "${var.name}-ec2-profile" })
}

# Scoped to this one bucket. ListBucket is a *bucket* action and GetObject /
# PutObject are *object* actions, which is why the two ARN forms differ.
resource "aws_iam_role_policy" "s3_access" {
  count = var.app_bucket_arn == null ? 0 : 1

  name = "${var.name}-s3-access"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListAppBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = var.app_bucket_arn
      },
      {
        Sid      = "ReadWriteAppObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${var.app_bucket_arn}/*"
      },
    ]
  })
}

# Lets SSM Session Manager open a shell without SSH, an open port, or a key
# pair. Works from a private subnet as long as there is outbound egress.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Required for the CloudWatch agent to create log streams and publish the
# memory/disk metrics EC2 does not report on its own.
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# ---------------------------------------------------------------------------
# Admin IAM user (task requirement 1)
#
# Deliberately created without an access key. aws_iam_access_key stores the
# secret in Terraform state in plaintext, where anyone with s3:GetObject on
# the state bucket can read it. Create credentials in the console, or better,
# replace this user with federated access.
# ---------------------------------------------------------------------------
resource "aws_iam_user" "admin" {
  count = var.create_admin_user ? 1 : 0

  name = "${var.name}-admin"
  path = "/"

  tags = merge(var.tags, { Name = "${var.name}-admin" })
}

resource "aws_iam_policy" "admin" {
  count = var.create_admin_user ? 1 : 0

  name        = "${var.name}-admin-policy"
  description = "Permissions from the architecture diagram: EC2, load balancers, S3, CloudWatch, SSH via bastion"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # "Create EC2" in the diagram. ec2:* is broad — it also covers VPC,
        # subnets and security groups, because they share the ec2 namespace.
        # Narrowing this to named actions is the obvious next hardening step.
        Sid      = "ManageEC2"
        Effect   = "Allow"
        Action   = "ec2:*"
        Resource = "*"
      },
      {
        Sid      = "ManageLoadBalancers"
        Effect   = "Allow"
        Action   = "elasticloadbalancing:*"
        Resource = "*"
      },
      {
        Sid    = "ManageAppBucket"
        Effect = "Allow"
        Action = "s3:*"
        # Both branches must be the same type — a conditional cannot return
        # a string on one side and a list on the other.
        Resource = var.app_bucket_arn == null ? ["*"] : [var.app_bucket_arn, "${var.app_bucket_arn}/*"]
      },
      {
        Sid    = "ListBuckets"
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation",
        ]
        Resource = "*"
      },
      {
        # "View CloudWatch" — read-only. No PutMetricAlarm, no DeleteAlarms.
        Sid    = "ViewCloudWatch"
        Effect = "Allow"
        Action = [
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "logs:Describe*",
          "logs:Get*",
          "logs:List*",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:FilterLogEvents",
        ]
        Resource = "*"
      },
      {
        # "SSH Access via Bastion" — Session Manager, so no inbound port 22
        # and every session is logged.
        Sid    = "SessionManagerAccess"
        Effect = "Allow"
        Action = [
          "ssm:StartSession",
          "ssm:TerminateSession",
          "ssm:ResumeSession",
          "ssm:DescribeSessions",
          "ssm:GetConnectionStatus",
          "ssm:DescribeInstanceInformation",
        ]
        Resource = "*"
      },
    ]
  })

  tags = merge(var.tags, { Name = "${var.name}-admin-policy" })
}

resource "aws_iam_user_policy_attachment" "admin" {
  count = var.create_admin_user ? 1 : 0

  user       = aws_iam_user.admin[0].name
  policy_arn = aws_iam_policy.admin[0].arn
}
