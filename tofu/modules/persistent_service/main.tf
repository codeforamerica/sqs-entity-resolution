module "task" {
  source = "../ephemeral_service"

  project                  = var.project
  environment              = var.environment
  service                  = var.service
  image_tag                = var.image_tag
  image_tags_mutable       = var.image_tags_mutable
  force_delete             = var.force_delete
  memory                   = var.memory
  otel_ssm_parameter_arn   = var.otel_ssm_parameter_arn
  otel_log_level           = var.otel_log_level
  logging_key_id           = var.logging_key_id
  task_policies            = var.task_policies
  untagged_image_retention = var.untagged_image_retention
  execution_policies       = var.execution_policies
  container_key_arn        = var.container_key_arn
  container_command        = var.container_command
  docker_context           = var.docker_context
  dockerfile               = var.dockerfile
  environment_secrets      = var.environment_secrets
  environment_variables    = var.environment_variables
  ephemeral_volumes        = var.ephemeral_volumes
  cpu                      = var.cpu

  tags = var.tags
}

module "service" {
  source  = "HENNGE/ecs/aws//modules/core/service"
  version = "5.3.0"

  cluster                      = var.cluster_name
  name                         = local.prefix
  create_task_definition       = false
  task_definition_arn          = module.task.task_definition_arn

  # Ignore changes to the desired count to prevent conflicts with auto-scaling.
  ignore_desired_count_changes = true

  launch_type                   = "FARGATE"
  task_requires_compatibilities = ["FARGATE"]
  enable_execute_command        = var.enable_execute_command
  propagate_tags                = "SERVICE"

  network_configuration = {
    subnets          = var.container_subnets
    security_groups  = var.security_groups
    assign_public_ip = false
  }

  tags = var.tags
}

module "scaling_target" {
  source  = "HENNGE/ecs/aws//modules/core/ecs-autoscaling-target"
  version = "5.3.0"

  ecs_cluster_name = var.cluster_name
  ecs_service_name = module.service.name
  min_capacity     = var.desired_containers
  max_capacity     = var.max_containers
}
