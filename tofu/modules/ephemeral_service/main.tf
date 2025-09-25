module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 3.0"

  repository_name                 = local.prefix
  repository_image_scan_on_push   = true
  repository_encryption_type      = "KMS"
  repository_force_delete         = var.force_delete
  repository_image_tag_mutability = var.image_tags_mutable ? "MUTABLE" : "IMMUTABLE"
  repository_kms_key              = var.container_key_arn
  repository_lifecycle_policy = jsonencode(yamldecode(templatefile(
    "${path.module}/templates/repository-lifecycle.yaml.tftpl", {
      untagged_image_retention : var.untagged_image_retention
    }
  )))

  tags = var.tags
}

module "ecs_task" {
  depends_on = [docker_registry_image.container]

  source  = "HENNGE/ecs/aws//modules/core/task"
  version = "~> 5.3"

  name   = local.prefix
  cpu    = var.cpu
  memory = var.memory
  # TODO: These roles?
  daemon_role              = aws_iam_role.execution.arn
  task_role                = aws_iam_role.task.arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  volume_configurations = [for name, path in var.ephemeral_volumes : { name = name }]

  container_definitions = jsonencode(yamldecode(templatefile(
    "${path.module}/templates/container-definitions.yaml.tftpl", {
      name              = local.prefix
      cpu               = var.cpu - 256
      memory            = var.memory - 512
      image             = "${module.ecr.repository_url}:${var.image_tag}"
      container_command = var.container_command
      container_port    = var.container_port
      log_group         = aws_cloudwatch_log_group.service.name
      region            = data.aws_region.current.region
      namespace         = "${var.project}/${var.service}"
      env_vars          = var.environment_variables
      otel_log_level    = var.otel_log_level
      otel_ssm_arn      = var.otel_ssm_parameter_arn
      env_secrets       = var.environment_secrets

      volumes = { for name, path in var.ephemeral_volumes : name => { name = name, mount = path } }
    }
  )))

  tags = var.tags
}
