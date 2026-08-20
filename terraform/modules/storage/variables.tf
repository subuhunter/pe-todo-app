variable "bucket_name" {
  description = "Globally unique bucket name. Callers usually suffix the AWS account ID."
  type        = string
}

variable "versioning_enabled" {
  description = "Keep previous versions of overwritten objects."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key for object encryption. Null uses SSE-S3 (AES256)."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete a non-empty bucket."
  type        = bool
  default     = false
}

variable "log_prefix" {
  description = "Key prefix the log expiry lifecycle rule applies to."
  type        = string
  default     = "logs/"
}

variable "log_retention_days" {
  description = "Days to keep objects under log_prefix before expiring them."
  type        = number
  default     = 30
}

variable "noncurrent_version_retention_days" {
  description = "Days to keep superseded object versions."
  type        = number
  default     = 30
}

variable "allow_alb_access_logs" {
  description = "Add a bucket policy statement letting the regional ELB log-delivery account write access logs."
  type        = bool
  default     = false
}

variable "alb_access_logs_prefix" {
  description = "Key prefix the ALB writes access logs under. Must match the ALB's access_logs_prefix."
  type        = string
  default     = "alb"
}

variable "tags" {
  description = "Extra tags merged onto the bucket."
  type        = map(string)
  default     = {}
}
