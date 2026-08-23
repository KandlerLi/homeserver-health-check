output "health_check_id" {
  description = "Route53 health check ID"
  value       = aws_route53_health_check.homeserver.id
}

output "alarm_name" {
  description = "CloudWatch alarm name"
  value       = aws_cloudwatch_metric_alarm.homeserver_unreachable.alarm_name
}

output "sns_topic_arn" {
  description = "SNS topic ARN alerts are published to"
  value       = aws_sns_topic.alerts.arn
}
