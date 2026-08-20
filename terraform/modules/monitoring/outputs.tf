output "log_group_name" {
  description = "Name of the application log group."
  value       = aws_cloudwatch_log_group.app.name
}

output "log_group_arn" {
  description = "ARN of the application log group."
  value       = aws_cloudwatch_log_group.app.arn
}

output "sns_topic_arn" {
  description = "ARN of the alarm topic, or null if not created."
  value       = try(aws_sns_topic.alarms[0].arn, null)
}

output "alarm_names" {
  description = "Every alarm this module created."
  value = concat(
    [for a in aws_cloudwatch_metric_alarm.cpu_high : a.alarm_name],
    [for a in aws_cloudwatch_metric_alarm.status_check : a.alarm_name],
    [for a in aws_cloudwatch_metric_alarm.unhealthy_hosts : a.alarm_name],
    [for a in aws_cloudwatch_metric_alarm.alb_5xx : a.alarm_name],
  )
}
