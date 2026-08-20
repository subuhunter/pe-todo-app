variable "name" {
  description = "Name prefix for resources in this module."
  type        = string
}

variable "vpc_id" {
  description = "VPC the load balancer and target group live in."
  type        = string
}

variable "subnet_ids" {
  description = "Public subnet IDs for the ALB nodes. At least two, in different AZs."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "An Application Load Balancer requires at least two subnets in two availability zones."
  }
}

variable "listener_port" {
  description = "Port the ALB listens on. 80 here; production should terminate TLS on 443 with an ACM certificate."
  type        = number
  default     = 80
}

variable "target_port" {
  description = "Port the ALB forwards to on each target."
  type        = number
  default     = 80
}

variable "target_group_name_prefix" {
  description = "Prefix for the generated target group name. AWS caps this at 6 characters."
  type        = string
  default     = "tg-"

  validation {
    condition     = length(var.target_group_name_prefix) <= 6
    error_message = "AWS limits aws_lb_target_group name_prefix to 6 characters."
  }
}

variable "ingress_cidrs" {
  description = "CIDR blocks allowed to reach the listener."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "health_check_path" {
  description = "Path the ALB requests to decide whether a target is healthy."
  type        = string
  default     = "/health"
}

variable "health_check_matcher" {
  description = "HTTP status codes counted as healthy."
  type        = string
  default     = "200"
}

variable "health_check_interval" {
  description = "Seconds between health checks."
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Seconds to wait for a health check response. Must be less than the interval."
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Consecutive successes before an unhealthy target is put back in rotation."
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Consecutive failures before a target is taken out of rotation."
  type        = number
  default     = 2
}

variable "deregistration_delay" {
  description = "Seconds to drain in-flight requests before removing a target."
  type        = number
  default     = 30
}

variable "idle_timeout" {
  description = "Seconds an idle connection is held open."
  type        = number
  default     = 60
}

variable "enable_deletion_protection" {
  description = "Block terraform destroy from deleting the load balancer."
  type        = bool
  default     = false
}

variable "access_logs_bucket" {
  description = <<-EOT
    S3 bucket for ALB access logs, or null to disable. The bucket policy must
    already allow the ELB log-delivery principal — see the storage module's
    allow_alb_access_logs input.
  EOT
  type        = string
  default     = null
}

variable "access_logs_prefix" {
  description = "Key prefix for access log objects."
  type        = string
  default     = "alb"
}

variable "tags" {
  description = "Extra tags merged onto every resource in this module."
  type        = map(string)
  default     = {}
}
