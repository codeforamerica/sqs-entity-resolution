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
}
