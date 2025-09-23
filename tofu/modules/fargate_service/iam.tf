resource "aws_iam_policy" "execution" {
  name        = "${local.prefix}-execution"
  description = "${var.service} task execution policy for ${var.project} ${var.environment}."

  policy = jsonencode(yamldecode(templatefile("${path.module}/templates/execution-policy.yaml.tftpl", {
    project     = var.project
    environment = var.environment
    ecr_arn     = local.repository_arn
  })))

  tags = var.tags
}

resource "aws_iam_role" "execution" {
  name        = "${local.prefix}-execution"
  description = "${var.service} task execution role for ${var.project} ${var.environment}."

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
}

resource "aws_iam_role_policy_attachments_exclusive" "execution" {
  role_name = aws_iam_role.execution.name
  # TODO: Create our own policy instead of using the managed ones.
  policy_arns = concat([
    # aws_iam_policy.execution.arn
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchAgentServerPolicy"
  ], var.execution_policies)
}

resource "aws_iam_role" "task" {
  name        = "${local.prefix}-task"
  description = "${var.service} task role for ${var.project} ${var.environment}."

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
}

resource "aws_iam_role_policy_attachments_exclusive" "task" {
  role_name = aws_iam_role.task.name
  # TODO: Create our own policy instead of using the managed ones.
  policy_arns = concat([
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchFullAccess",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMFullAccess",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchAgentServerPolicy",
  ], var.task_policies)
}
