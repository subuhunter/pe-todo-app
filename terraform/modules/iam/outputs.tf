output "instance_profile_name" {
  description = "Instance profile name — this is what aws_instance.iam_instance_profile expects."
  value       = aws_iam_instance_profile.ec2.name
}

output "instance_profile_arn" {
  description = "ARN of the instance profile."
  value       = aws_iam_instance_profile.ec2.arn
}

output "role_name" {
  description = "Name of the EC2 role."
  value       = aws_iam_role.ec2.name
}

output "role_arn" {
  description = "ARN of the EC2 role."
  value       = aws_iam_role.ec2.arn
}

output "admin_user_name" {
  description = "Name of the admin IAM user, or null if not created."
  value       = try(aws_iam_user.admin[0].name, null)
}

output "admin_user_arn" {
  description = "ARN of the admin IAM user, or null if not created."
  value       = try(aws_iam_user.admin[0].arn, null)
}

output "admin_policy_arn" {
  description = "ARN of the admin policy, or null if not created."
  value       = try(aws_iam_policy.admin[0].arn, null)
}
