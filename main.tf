data "aws_caller_identity" "current" {}

# Fixes trivy's AWS-0136 (SNS topic encryption should use a customer
# managed key, not the AWS-managed default). Dedicated to this one
# topic, not shared account-wide the way bootstrap/terraform-state's
# own shared_kms_key.tf is: that key lives in eu-central-1 and can't
# encrypt anything here, since this repo's entire provider is pinned to
# us-east-1 (see versions.tf's own comment). A single-consumer,
# region-specific key doesn't need the cross-repo alias-lookup pattern
# the shared key uses -- just a direct resource reference within this
# same root.
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
        # CloudWatch Alarms' own required key-policy shape for
        # publishing to an SSE-KMS-encrypted SNS topic, per AWS's own
        # documentation for this exact scenario
        # (sns-key-management.html, "Enable compatibility between
        # event sources from AWS services and encrypted topics") --
        # same shape as bootstrap/terraform-state's own
        # AllowCloudWatchAlarmsToPublishToSNS statement, just scoped to
        # this one key instead of the shared one.
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

  # Fixes trivy's AWS-0095/AWS-0136 (topic should be encrypted with a
  # customer managed key) -- see aws_kms_key.alerts above for why this
  # is its own dedicated key rather than the workspace's shared one.
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

  # Notify on both going unhealthy and recovering -- knowing it's back up
  # matters as much as knowing it went down.
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}
