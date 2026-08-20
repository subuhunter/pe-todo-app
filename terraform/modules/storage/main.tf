terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# The AWS-owned account that writes ALB access logs differs per region. This
# data source knows the mapping for regions launched before August 2022;
# newer regions instead use the logdelivery.elasticloadbalancing.amazonaws.com
# service principal and will need this statement rewritten.
data "aws_elb_service_account" "this" {
  count = var.allow_alb_access_logs ? 1 : 0
}

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name

  # Dev convenience: lets terraform destroy delete a bucket that still holds
  # logs. Set this to false for anything you would miss.
  force_destroy = var.force_destroy

  tags = merge(var.tags, { Name = var.bucket_name })
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Disables ACLs entirely, so every object is owned by this account no matter
# who wrote it. Without this, objects the ELB log-delivery account writes
# would be owned by AWS and unreadable here.
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid       = "DenyInsecureTransport"
          Effect    = "Deny"
          Principal = "*"
          Action    = "s3:*"
          Resource = [
            aws_s3_bucket.this.arn,
            "${aws_s3_bucket.this.arn}/*",
          ]
          Condition = {
            Bool = { "aws:SecureTransport" = "false" }
          }
        },
      ],
      var.allow_alb_access_logs ? [
        {
          Sid    = "AllowALBAccessLogs"
          Effect = "Allow"
          Principal = {
            AWS = data.aws_elb_service_account.this[0].arn
          }
          Action   = "s3:PutObject"
          Resource = "${aws_s3_bucket.this.arn}/${var.alb_access_logs_prefix}/*"
        },
      ] : [],
    )
  })

  # A bucket policy applied before the public access block can be rejected as
  # a "public" policy. Order them explicitly.
  depends_on = [aws_s3_bucket_public_access_block.this]
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    filter {
      prefix = var.log_prefix
    }

    expiration {
      days = var.log_retention_days
    }
  }

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}
