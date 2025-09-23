module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 3.0"

  repository_name                 = local.prefix
  repository_image_scan_on_push   = true
  repository_encryption_type      = "KMS"
  repository_force_delete         = var.force_delete
  repository_image_tag_mutability = var.image_tags_mutable ? "MUTABLE" : "IMMUTABLE"
  repository_kms_key              = aws_kms_key.fargate.arn
  repository_lifecycle_policy = jsonencode(yamldecode(templatefile(
    "${path.module}/templates/repository-lifecycle.yaml.tftpl", {
      untagged_image_retention : var.untagged_image_retention
    }
  )))

  tags = var.tags
}

module "ecs_service" {
  source  = "HENNGE/ecs/aws//modules/simple/fargate"
  version = "~> 5.3"

  name                   = local.prefix
  cluster                = var.cluster_arn
  container_name         = local.prefix
  cpu                    = var.cpu
  memory                 = var.memory
  desired_count          = var.desired_containers
  vpc_subnets            = var.container_subnets
  security_groups        = var.security_groups
  iam_daemon_role        = aws_iam_role.execution.arn
  iam_task_role          = aws_iam_role.task.arn
  enable_execute_command = var.enable_execute_command
  force_delete           = var.force_delete

  container_definitions = jsonencode(yamldecode(templatefile(
    "${path.module}/templates/container_definitions.yaml.tftpl", {
      name              = local.prefix
      cpu               = var.cpu - 256
      memory            = var.memory - 512
      image             = "${local.image_url}:${local.image_tag}"
      container_command = var.container_command
      container_port    = var.container_port
      log_group         = aws_cloudwatch_log_group.service.name
      region            = data.aws_region.current.region
      namespace         = "${var.project}/${var.service}"
      env_vars          = var.environment_variables
      otel_log_level    = var.otel_log_level
      otel_ssm_arn      = module.otel_config.ssm_parameter_arn
      env_secrets       = var.environment_secrets
      volumes           = {}
    }
  )))

  tags = var.tags
}
