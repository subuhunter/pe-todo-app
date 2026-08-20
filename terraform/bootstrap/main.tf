terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Intentionally local state. This stack creates the bucket that every other
  # stack stores its state in, so it cannot store its own state there.
}

provider "aws" {
  region = var.aws_region

  # Guardrail against a stale AWS_PROFILE creating the state bucket in the
  # wrong account. An empty list disables the check.
  allowed_account_ids = var.allowed_account_ids

  default_tags {
    tags = {
      Project   = var.project_name
      Purpose   = "terraform-state"
      ManagedBy = "terraform"
    }
  }
}

resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name

  # Guards against a stray `terraform destroy` taking every stack's state
  # with it. Remove this before you intentionally tear the bucket down.
  lifecycle {
    prevent_destroy = true
  }
}

# Versioning is what makes state recoverable after a bad apply or a corrupt write.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# State files contain secrets in plaintext — refuse any unencrypted transport.
resource "aws_s3_bucket_policy" "deny_insecure_transport" {
  bucket = aws_s3_bucket.state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.state.arn,
        "${aws_s3_bucket.state.arn}/*",
      ]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.state]
}

# Expire old state versions so the bucket doesn't grow without bound.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-noncurrent-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}
