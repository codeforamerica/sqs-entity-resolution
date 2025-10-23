resource "aws_iam_policy" "exports" {
  name_prefix = "${local.prefix}-exports-access-"
  description = "Allow access to the S3 bucket for Senzing exports."

  policy = jsonencode(yamldecode(templatefile("${path.module}/templates/exports-access-policy.yaml.tftpl", {
    bucket_arn = module.s3.arn
    kms_arn    = aws_kms_key.queue.arn
  })))

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_policy" "queue" {
  name_prefix = "${local.prefix}-queue-access-"
  description = "Allow access to the SQS queues for Senzing."

  policy = jsonencode(yamldecode(templatefile("${path.module}/templates/queue-access-policy.yaml.tftpl", {
    queues = [
      module.sqs.queue_arn,
    ]
    kms_arn = aws_kms_key.queue.arn
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
      aws_ssm_parameter.otel_config.arn,
      aws_ssm_parameter.senzing_config.arn,
      module.database.cluster_master_user_secret[0].secret_arn,
    ]
    kms_arn = aws_kms_key.container.arn
  })))

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "eventbridge" {
  name = "${local.prefix}-eventbridge-run-task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "events.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "eventbridge" {
  name = "${local.prefix}-eventbridge-run-task"
  role = aws_iam_role.eventbridge.id

  policy = jsonencode(yamldecode(templatefile("${path.module}/templates/eventbridge-policy.yaml.tftpl", {
    export_task_arn    = module.exporter.task_definition_arn
    execution_role_arn = module.exporter.execution_role_arn
    task_role_arn      = module.exporter.task_role_arn
  })))
}
