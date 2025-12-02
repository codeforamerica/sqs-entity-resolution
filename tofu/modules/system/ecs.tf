module "task_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.1"

  name   = "${local.prefix}-task"
  vpc_id = var.vpc_id

  egress_cidr_blocks      = [data.aws_vpc.current.cidr_block]
  egress_ipv6_cidr_blocks = data.aws_vpc.current.ipv6_cidr_block != "" ? [data.aws_vpc.current.ipv6_cidr_block] : []
  egress_rules            = ["https-443-tcp", "postgresql-tcp"]

  tags = var.tags
}

resource "aws_kms_key" "container" {
  description             = "Encryption key for Senzing containers."
  deletion_window_in_days = var.key_recovery_period
  enable_key_rotation     = true
  policy = jsonencode(yamldecode(templatefile("${path.module}/templates/container-key-policy.yaml.tftpl", {
    account_id : data.aws_caller_identity.identity.account_id,
    environment : var.environment,
    partition : data.aws_partition.current.partition,
    project : var.project,
    region : data.aws_region.current.region,
  })))

  tags = var.tags
}

resource "aws_kms_alias" "container" {
  name          = "alias/${var.project}/${var.environment}/container"
  target_key_id = aws_kms_key.container.id
}

resource "aws_ssm_parameter" "senzing_config" {
  name        = "/${var.project}/${var.environment}/senzing"
  description = "Configuration for Senzing."
  tier        = "Intelligent-Tiering"
  type        = "SecureString"
  overwrite   = true
  key_id      = aws_kms_key.container.arn

  value = jsonencode(yamldecode(templatefile("${path.module}/templates/senzing-config.yaml.tftpl", {
    database_host : module.database.cluster_endpoint
    database_username : jsondecode(data.aws_secretsmanager_secret_version.database.secret_string).username
    database_password : urlencode(jsondecode(data.aws_secretsmanager_secret_version.database.secret_string).password)
    senzing_license_base64 : coalesce(var.senzing_license_base64, " ")
  })))

  tags = var.tags
}

module "ecs" {
  source  = "HENNGE/ecs/aws"
  version = "~> 5.3"

  name                        = local.prefix
  capacity_providers          = ["FARGATE"]
  enable_container_insights   = true
  container_insights_enhanced = true

  tags = var.tags
}

module "consumer" {
  source     = "../persistent_service"
  depends_on = [aws_iam_policy.queue, aws_iam_policy.secrets]

  project                  = var.project
  environment              = var.environment
  service                  = "consumer"
  image_tag                = var.image_tag
  image_tags_mutable       = var.image_tags_mutable
  force_delete             = !var.deletion_protection
  container_key_arn        = aws_kms_key.container.arn
  logging_key_id           = var.logging_key_arn
  otel_ssm_parameter_arn   = aws_ssm_parameter.otel_config.arn
  execution_policies       = [aws_iam_policy.secrets.arn]
  task_policies            = [aws_iam_policy.queue.arn]
  security_groups          = [module.task_security_group.security_group_id]
  cluster_name             = module.ecs.name
  container_subnets        = var.container_subnets
  desired_containers       = var.consumer_container_count
  max_containers           = var.consumer_container_max
  cpu                      = var.consumer_cpu
  memory                   = var.consumer_memory
  dockerfile               = "Dockerfile.consumer"
  docker_context           = "${path.module}/../../../"
  scale_up_policy          = { step : var.consumer_message_threshold, start : 1 }
  scale_down_policy        = {}
  untagged_image_retention = var.untagged_image_retention
  otel_ecr_arn             = module.otel_ecr.repository_arn
  otel_image               = docker_registry_image.otel.name

  environment_variables = {
    LOG_LEVEL : var.log_level
    OTEL_EXPORTER_OTLP_ENDPOINT = "http://localhost:4318"
    OTEL_USE_OTLP_EXPORTER : true
    PGHOST : module.database.cluster_endpoint
    Q_URL : module.sqs.queue_url
    RUNTIME_ENV : var.environment
  }

  environment_secrets = {
    PGPASSWORD : "${module.database.cluster_master_user_secret[0].secret_arn}:password::"
    PGUSER : "${module.database.cluster_master_user_secret[0].secret_arn}:username::"
    SENZING_ENGINE_CONFIGURATION_JSON = aws_ssm_parameter.senzing_config.arn
  }

  tags = var.tags
}

module "redoer" {
  source     = "../persistent_service"
  depends_on = [aws_iam_policy.secrets]

  project                  = var.project
  environment              = var.environment
  service                  = "redoer"
  image_tag                = var.image_tag
  image_tags_mutable       = var.image_tags_mutable
  force_delete             = !var.deletion_protection
  container_key_arn        = aws_kms_key.container.arn
  logging_key_id           = var.logging_key_arn
  otel_ssm_parameter_arn   = aws_ssm_parameter.otel_config.arn
  execution_policies       = [aws_iam_policy.secrets.arn]
  task_policies            = [aws_iam_policy.queue.arn]
  security_groups          = [module.task_security_group.security_group_id]
  cluster_name             = module.ecs.name
  container_subnets        = var.container_subnets
  desired_containers       = var.redoer_container_count
  max_containers           = var.redoer_container_count > 1 ? var.redoer_container_count : 1
  cpu                      = var.redoer_cpu
  memory                   = var.redoer_memory
  dockerfile               = "Dockerfile.redoer"
  docker_context           = "${path.module}/../../../"
  scale_up_policy          = {}
  scale_down_policy        = {}
  untagged_image_retention = var.untagged_image_retention
  otel_ecr_arn             = module.otel_ecr.repository_arn
  otel_image               = docker_registry_image.otel.name

  environment_variables = {
    LOG_LEVEL : var.log_level
    OTEL_EXPORTER_OTLP_ENDPOINT = "http://localhost:4318"
    OTEL_USE_OTLP_EXPORTER : true
    PGHOST : module.database.cluster_endpoint
    Q_URL : module.sqs.queue_url
    RUNTIME_ENV : var.environment
  }

  environment_secrets = {
    PGPASSWORD : "${module.database.cluster_master_user_secret[0].secret_arn}:password::"
    PGUSER : "${module.database.cluster_master_user_secret[0].secret_arn}:username::"
    SENZING_ENGINE_CONFIGURATION_JSON = aws_ssm_parameter.senzing_config.arn
  }

  tags = var.tags
}

module "exporter" {
  source     = "../ephemeral_service"
  depends_on = [aws_iam_policy.exports, aws_iam_policy.secrets]

  project                  = var.project
  environment              = var.environment
  service                  = "exporter"
  image_tag                = var.image_tag
  image_tags_mutable       = var.image_tags_mutable
  force_delete             = !var.deletion_protection
  container_key_arn        = aws_kms_key.container.arn
  logging_key_id           = var.logging_key_arn
  otel_ssm_parameter_arn   = aws_ssm_parameter.otel_config.arn
  execution_policies       = [aws_iam_policy.secrets.arn]
  task_policies            = [aws_iam_policy.exports.arn]
  dockerfile               = "Dockerfile.exporter"
  docker_context           = "${path.module}/../../../"
  untagged_image_retention = var.untagged_image_retention
  otel_ecr_arn             = module.otel_ecr.repository_arn
  otel_image               = docker_registry_image.otel.name

  environment_variables = {
    LOG_LEVEL : var.log_level
    OTEL_EXPORTER_OTLP_ENDPOINT = "http://localhost:4318"
    OTEL_USE_OTLP_EXPORTER : true
    PGHOST : module.database.cluster_endpoint
    Q_URL : module.sqs.queue_url
    RUNTIME_ENV : var.environment
    S3_BUCKET_NAME : module.s3.bucket
  }

  environment_secrets = {
    PGPASSWORD : "${module.database.cluster_master_user_secret[0].secret_arn}:password::"
    PGUSER : "${module.database.cluster_master_user_secret[0].secret_arn}:username::"
    SENZING_ENGINE_CONFIGURATION_JSON = aws_ssm_parameter.senzing_config.arn
  }

  tags = var.tags
}

module "tools" {
  source     = "../ephemeral_service"
  depends_on = [aws_iam_policy.queue, aws_iam_policy.secrets]

  project                  = var.project
  environment              = var.environment
  service                  = "tools"
  image_tag                = var.image_tag
  image_tags_mutable       = var.image_tags_mutable
  force_delete             = !var.deletion_protection
  container_key_arn        = aws_kms_key.container.arn
  logging_key_id           = var.logging_key_arn
  otel_ssm_parameter_arn   = aws_ssm_parameter.otel_config.arn
  execution_policies       = [aws_iam_policy.secrets.arn]
  task_policies            = [aws_iam_policy.exports.arn, aws_iam_policy.queue.arn]
  dockerfile               = "Dockerfile.tools"
  docker_context           = "${path.module}/../../../"
  untagged_image_retention = var.untagged_image_retention
  otel_ecr_arn             = module.otel_ecr.repository_arn
  otel_image               = docker_registry_image.otel.name

  ephemeral_volumes = {
    senzing-home = "/home/senzing"
    # We need these to support ecs exec with a read-only root filesystem.
    aws-lib = "/var/lib/amazon"
    logs    = "/var/log"
  }

  environment_variables = {
    LOG_LEVEL : var.log_level
    OTEL_EXPORTER_OTLP_ENDPOINT = "http://localhost:4318"
    OTEL_USE_OTLP_EXPORTER : true
    PGHOST : module.database.cluster_endpoint
    PGSSLMODE : "require"
    Q_URL : module.sqs.queue_url
    RUNTIME_ENV : var.environment
    S3_BUCKET_NAME : module.s3.bucket
  }

  environment_secrets = {
    PGPASSWORD : "${module.database.cluster_master_user_secret[0].secret_arn}:password::"
    PGUSER : "${module.database.cluster_master_user_secret[0].secret_arn}:username::"
    SENZING_ENGINE_CONFIGURATION_JSON = aws_ssm_parameter.senzing_config.arn
  }

  tags = var.tags
}
