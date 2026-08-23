resource "aws_route53_health_check" "homeserver" {
  fqdn              = var.fqdn
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "homeserver-reachability"
  }
}

resource "aws_sns_topic" "alerts" {
  name = "homeserver-health-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "homeserver_unreachable" {
  alarm_name        = "homeserver-unreachable"
  alarm_description = "${var.fqdn} (home network) is not responding to HTTPS health checks"

  namespace   = "AWS/Route53"
  metric_name = "HealthCheckStatus"
  dimensions = {
    HealthCheckId = aws_route53_health_check.homeserver.id
  }

  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "LessThanThreshold"

  # Notify on both going unhealthy and recovering -- knowing it's back up
  # matters as much as knowing it went down.
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}
