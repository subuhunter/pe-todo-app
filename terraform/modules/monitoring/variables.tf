variable "name" {
  description = "Name prefix for monitoring resources."
  type        = string
}

variable "instance_ids" {
  description = <<-EOT
    Map of a stable label -> EC2 instance ID. The label becomes part of the
    alarm name, so use "web-1" rather than an index — renaming a key destroys
    and recreates that alarm.
  EOT
  type        = map(string)
  default     = {}
}

variable "log_group_name" {
  description = "CloudWatch log group name. Null derives /aws/ec2/<name>. Must match what the CloudWatch agent config on the instances writes to."
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "Days to retain log events. 0 means never expire."
  type        = number
  default     = 14
}

variable "create_sns_topic" {
  description = "Create an SNS topic for alarm notifications."
  type        = bool
  default     = true
}

variable "alarm_email" {
  description = "Email address to subscribe to the alarm topic. The recipient must confirm the subscription by email."
  type        = string
  default     = null
}

variable "alarm_action_arns" {
  description = "Existing notification targets, used only when create_sns_topic is false."
  type        = list(string)
  default     = []
}

variable "cpu_threshold" {
  description = "CPU percentage above which the high-CPU alarm fires."
  type        = number
  default     = 80
}

variable "alarm_period" {
  description = "Seconds per datapoint. Basic EC2 monitoring publishes every 300s; anything shorter needs detailed monitoring enabled."
  type        = number
  default     = 300
}

variable "evaluation_periods" {
  description = "Consecutive breaching periods before the alarm fires."
  type        = number
  default     = 2
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for the LoadBalancer dimension. Null skips the load balancer alarms."
  type        = string
  default     = null
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix for the TargetGroup dimension. Null skips the unhealthy-host alarm."
  type        = string
  default     = null
}

variable "alb_5xx_threshold" {
  description = "Number of ELB-generated 5xx responses in a period before alarming."
  type        = number
  default     = 5
}

variable "tags" {
  description = "Extra tags merged onto monitoring resources."
  type        = map(string)
  default     = {}
}
