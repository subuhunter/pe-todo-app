variable "name" {
  description = "Name prefix for IAM resources. IAM is global, so this must be unique per account, not per region."
  type        = string
}

variable "app_bucket_arn" {
  description = "ARN of the application S3 bucket the instance role may read and write. Null skips the S3 policy."
  type        = string
  default     = null
}

variable "create_admin_user" {
  description = "Create the admin IAM user from the architecture diagram. No access key is generated."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags merged onto IAM resources."
  type        = map(string)
  default     = {}
}
