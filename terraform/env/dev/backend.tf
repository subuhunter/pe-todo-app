# Remote state for the DEV environment, with S3-native locking
# (use_lockfile, Terraform 1.10+).
#
# Backend blocks cannot use variables or interpolation — Terraform evaluates
# this before variables exist, so every value must be a literal. Keep `bucket`
# in sync with `state_bucket_name` in bootstrap/terraform.tfvars, and `region`
# with the bucket's real region.
#
# `key` is what keeps this environment's state separate from qa/production.
# All three share one bucket and differ only by key prefix.
terraform {
  backend "s3" {
    bucket       = "platform-demo-tfstate-354389687178"
    key          = "ec2-demo/dev/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
