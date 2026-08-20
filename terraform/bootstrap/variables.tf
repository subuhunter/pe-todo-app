variable "aws_region" {
  description = "Region the state bucket lives in. Must match `region` in ../env/dev/backend.tf."
  type        = string
  default     = "ap-south-1"
}

variable "allowed_account_ids" {
  description = "AWS account IDs this stack may apply to. Empty list disables the check."
  type        = list(string)
  default     = ["354389687178"]
}

variable "project_name" {
  description = "Short name used to build the bucket name."
  type        = string
  default     = "platform-demo"
}

variable "state_bucket_name" {
  description = <<-EOT
    Name of the state bucket. Must match `bucket` in ../env/dev/backend.tf exactly —
    the backend block can't use variables, so this is set in two places.
    S3 bucket names are globally unique; suffix it with your account ID.
  EOT
  type        = string
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key for state encryption. Null uses SSE-S3 (AES256)."
  type        = string
  default     = null
}

variable "noncurrent_version_retention_days" {
  description = "How long to keep superseded state versions before expiring them."
  type        = number
  default     = 90
}
