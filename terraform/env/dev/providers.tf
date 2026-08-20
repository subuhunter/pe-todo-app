provider "aws" {
  region = var.aws_region

  # Fails fast if the ambient credentials point at the wrong account. Nothing
  # else in this stack asserts *which* AWS account it is talking to — a stale
  # AWS_PROFILE would otherwise apply the dev config somewhere else entirely
  # and succeed. This is the account-level counterpart to the `environment`
  # validation in variables.tf.
  #
  # An empty list disables the check.
  allowed_account_ids = var.allowed_account_ids

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
