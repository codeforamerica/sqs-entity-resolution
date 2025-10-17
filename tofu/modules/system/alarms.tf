resource "aws_cloudwatch_metric_alarm" "queue_active" {
  alarm_name          = "${local.prefix}-queue-active"
  alarm_description   = "Monitor for active messages in the ingestion queue to scale service containers."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"
  period              = 60
  threshold           = 1

  dimensions = {
    QueueName = module.sqs.queue_name
  }

  alarm_actions = [
    module.consumer.scale_up_policy_arn,
    module.redoer.scale_up_policy_arn
  ]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "queue_empty" {
  alarm_name          = "${local.prefix}-queue-empty"
  alarm_description   = "Monitor for an empty ingestion queue to scale down service containers."
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = var.queue_empty_threshold
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  statistic           = "Maximum"
  treat_missing_data  = "breaching"
  period              = 60
  threshold           = 0

  dimensions = {
    QueueName = module.sqs.queue_name
  }

  alarm_actions = [
    module.consumer.scale_down_policy_arn,
    module.redoer.scale_down_policy_arn
  ]

  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "export" {
  name          = "${local.prefix}-queue-empty-export"
  description   = "Run the exporter task when the ingestion queue is empty."
  force_destroy = !var.deletion_protection

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"],
    detail-type = ["CloudWatch Alarm State Change"],
    resources   = [aws_cloudwatch_metric_alarm.queue_empty.arn],
    detail = {
      state         = { value = ["ALARM"] },
      previousState = { value = ["OK", "INSUFFICIENT_DATA"] }
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "exporter" {
  rule          = aws_cloudwatch_event_rule.export.name
  arn           = module.ecs.arn
  role_arn      = aws_iam_role.eventbridge.arn
  force_destroy = !var.deletion_protection
  target_id     = "export"

  ecs_target {
    task_definition_arn     = module.exporter.task_definition_arn
    launch_type             = "FARGATE"
    task_count              = 1
    propagate_tags          = "TASK_DEFINITION"
    enable_ecs_managed_tags = true

    network_configuration {
      subnets          = var.container_subnets
      security_groups  = [module.task_security_group.security_group_id]
      assign_public_ip = false
    }
  }
}
