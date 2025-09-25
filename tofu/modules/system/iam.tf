resource "aws_iam_policy" "queue" {
  name_prefix = "${local.prefix}-queue-access-"
  description = "Allow access to the SQS queues for Senzing."

  policy = jsonencode(yamldecode(templatefile("${path.module}/templates/queue-access-policy.yaml.tftpl", {
    queues = [
      module.sqs.queue_arn,
    ]
  })))

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_policy" "secrets" {
  name_prefix = "${local.prefix}-secrets-access-"
  description = "Allow access to secrets required for Senzing."

  policy = jsonencode(yamldecode(templatefile("${path.module}/templates/secrets-access-policy.yaml.tftpl", {
    secrets = [
      module.otel_config.ssm_parameter_arn,
      module.senzing_config.ssm_parameter_arn,
      module.database.cluster_master_user_secret[0].secret_arn,
    ]
    kms_arn = aws_kms_key.container.arn
  })))

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}
