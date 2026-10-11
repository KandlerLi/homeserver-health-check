data "aws_caller_identity" "current" {}

# Own key, not the shared CMK: see README, "Why us-east-1, with its own KMS key".
resource "aws_kms_key" "alerts" {
  description             = "CMK for homeserver-health-check's own SNS alert topic"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        # AWS's required shape for CloudWatch Alarms publishing to an SSE-KMS SNS topic.
        Sid    = "AllowCloudWatchAlarmsToPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
    ]
  })
}

resource "aws_kms_alias" "alerts" {
  name          = "alias/homeserver-health-check"
  target_key_id = aws_kms_key.alerts.key_id
}

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

  kms_master_key_id = aws_kms_key.alerts.arn
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

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}
