resource "aws_kms_key" "fargate" {
  description             = "${var.service} hosting encryption key for ${var.project} ${var.environment}"
  deletion_window_in_days = var.key_recovery_period
  enable_key_rotation     = true
  policy = jsonencode(yamldecode(templatefile("${path.module}/templates/key-policy.yaml.tftpl", {
    account_id : data.aws_caller_identity.identity.account_id,
    exec_role_arn : aws_iam_role.execution.arn,
    partition : data.aws_partition.current.partition,
    region : data.aws_region.current.region,
    repository_name : local.prefix,
  })))

  tags = var.tags
}

resource "aws_kms_alias" "fargate" {
  name          = "alias/${var.project}/${var.environment}/${var.service}"
  target_key_id = aws_kms_key.fargate.id
}
