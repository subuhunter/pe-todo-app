output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.this.id
}

output "instance_arn" {
  description = "ARN of the EC2 instance."
  value       = aws_instance.this.arn
}

output "public_ip" {
  description = "Public IP, if one was assigned."
  value       = aws_instance.this.public_ip
}

output "private_ip" {
  description = "Private IP of the instance."
  value       = aws_instance.this.private_ip
}

output "security_group_id" {
  description = "ID of the security group attached to the instance."
  value       = aws_security_group.this.id
}
