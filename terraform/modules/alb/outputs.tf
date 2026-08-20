output "arn" {
  description = "ARN of the load balancer."
  value       = aws_lb.this.arn
}

output "arn_suffix" {
  description = "ARN suffix — the form CloudWatch alarms need for the LoadBalancer dimension."
  value       = aws_lb.this.arn_suffix
}

output "dns_name" {
  description = "Public DNS name of the load balancer. This is the site's address."
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "Hosted zone ID of the ALB, for a Route 53 alias record."
  value       = aws_lb.this.zone_id
}

output "security_group_id" {
  description = "ALB security group. Targets should allow ingress from this ID, not from a CIDR."
  value       = aws_security_group.this.id
}

output "target_group_arn" {
  description = "ARN of the target group. Attach instances to this."
  value       = aws_lb_target_group.this.arn
}

output "target_group_arn_suffix" {
  description = "Target group ARN suffix, for the CloudWatch TargetGroup dimension."
  value       = aws_lb_target_group.this.arn_suffix
}

output "listener_arn" {
  description = "ARN of the HTTP listener."
  value       = aws_lb_listener.this.arn
}
