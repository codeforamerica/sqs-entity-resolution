resource "aws_iam_policy" "execution" {
  name        = "${local.prefix}-execution"
  description = "Senzing task execution policy."

  policy = jsonencode(yamldecode(templatefile("${path.module}/templates/execution-policy.yaml.tftpl", {
    project     = var.project
    environment = var.environment
    ecr_arn     = module.ecr.repository_arn
  })))

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "execution" {
  name        = "${local.prefix}-execution"
  description = "Senzing task execution role."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy_attachments_exclusive" "execution" {
  role_name = aws_iam_role.execution.name
  policy_arns = concat([
    aws_iam_policy.execution.arn
  ], var.execution_policies)
}

resource "aws_iam_policy" "task" {
  name        = "${local.prefix}-task"
  description = "Senzing task policy."

  policy = jsonencode(yamldecode(templatefile("${path.module}/templates/task-policy.yaml.tftpl", {
    account_id  = data.aws_caller_identity.identity.account_id
    partition   = data.aws_partition.current.partition
    project     = var.project
    region      = data.aws_region.current.region
    environment = var.environment
    ecr_arn     = module.ecr.repository_arn
  })))

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "task" {
  name        = "${local.prefix}-task"
  description = "Senzing task role."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy_attachments_exclusive" "task" {
  role_name = aws_iam_role.task.name
  policy_arns = concat([
    aws_iam_policy.task.arn,
  ], var.task_policies)
}
