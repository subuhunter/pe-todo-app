# ---------------------------------------------------------------------------
# The one you actually want
# ---------------------------------------------------------------------------

output "website_url" {
  description = "Open this. Targets need ~2 minutes after apply to pass health checks and start serving."
  value       = "http://${module.alb.dns_name}"
}

output "alb_dns_name" {
  description = "Public DNS name of the load balancer."
  value       = module.alb.dns_name
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Map of public subnet key -> subnet ID."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Map of private subnet key -> subnet ID."
  value       = module.network.private_subnet_ids
}

output "nat_gateway_public_ip" {
  description = "The address the private instances appear as when they reach the internet."
  value       = module.network.nat_gateway_public_ip
}

output "s3_vpc_endpoint_id" {
  description = "S3 gateway endpoint, or null if disabled."
  value       = module.network.s3_vpc_endpoint_id
}

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------

output "bastion_public_ip" {
  description = "Public IP of the bastion host."
  value       = module.bastion.public_ip
}

output "bastion_instance_id" {
  description = "Instance ID of the bastion host."
  value       = module.bastion.instance_id
}

output "web_instance_ids" {
  description = "Map of web server key -> instance ID."
  value       = { for k, m in module.web : k => m.instance_id }
}

output "web_private_ips" {
  description = "Map of web server key -> private IP. These have no public address by design."
  value       = { for k, m in module.web : k => m.private_ip }
}

# ---------------------------------------------------------------------------
# Storage, IAM, monitoring
# ---------------------------------------------------------------------------

output "app_bucket_name" {
  description = "Application bucket holding boot reports under test/ and Apache logs under logs/."
  value       = module.storage.bucket_id
}

output "admin_user_name" {
  description = "Admin IAM user, or null if not created. Created without an access key on purpose."
  value       = module.iam.admin_user_name
}

output "instance_profile_name" {
  description = "Instance profile the servers use to reach S3, CloudWatch and SSM."
  value       = module.iam.instance_profile_name
}

output "log_group_name" {
  description = "CloudWatch log group receiving Apache and cloud-init logs."
  value       = module.monitoring.log_group_name
}

output "alarm_topic_arn" {
  description = "SNS topic the alarms publish to."
  value       = module.monitoring.sns_topic_arn
}

output "alarm_names" {
  description = "Every CloudWatch alarm created by this stack."
  value       = module.monitoring.alarm_names
}

# ---------------------------------------------------------------------------
# Convenience
# ---------------------------------------------------------------------------

output "ssh_to_bastion" {
  description = "Command to reach the bastion. Requires key_name to be set and your IP in allowed_ssh_cidrs."
  value       = var.key_name == null ? "key_name is unset — use: aws ssm start-session --target ${module.bastion.instance_id} --region ${var.aws_region}" : "ssh -A -i ~/.ssh/${var.key_name}.pem ec2-user@${module.bastion.public_ip}"
}

output "ssm_session_commands" {
  description = "Session Manager commands for each web server. No SSH key, no open port, session is audited."
  value       = { for k, m in module.web : k => "aws ssm start-session --target ${m.instance_id} --region ${var.aws_region}" }
}
