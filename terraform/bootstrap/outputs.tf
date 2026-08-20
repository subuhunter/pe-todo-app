output "state_bucket_name" {
  description = "Bucket name — must match `bucket` in ../env/*/backend.tf."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN of the state bucket."
  value       = aws_s3_bucket.state.arn
}

output "state_bucket_region" {
  description = "Bucket region — must match `region` in ../env/*/backend.tf."
  value       = var.aws_region
}
