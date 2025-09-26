module "task_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.1"

  name   = "${local.prefix}-task"
  vpc_id = var.vpc_id

  # TODO: Copy the OTEL image to a private ECR repo and restrict egress to
  # within the VPC.
  # egress_cidr_blocks      = [data.aws_vpc.current.cidr_block]
  # egress_ipv6_cidr_blocks = data.aws_vpc.current.ipv6_cidr_block != "" ? [data.aws_vpc.current.ipv6_cidr_block] : []
  egress_cidr_blocks      = ["0.0.0.0/0"]
  egress_ipv6_cidr_blocks = ["::/0"]
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

module "otel_config" {
  source  = "terraform-aws-modules/ssm-parameter/aws"
  version = "~> 1.1"

  name        = "/${var.project}/${var.environment}/otel"
  description = "Configuration for the OpenTelemetry collector."
  tier        = "Intelligent-Tiering"
  type        = "SecureString"
  key_id      = aws_kms_key.container.arn
  secure_type = true
  value = templatefile("${path.module}/templates/aws-otel-config.yaml.tftpl", {
    app_namespace = "${var.project}/${var.environment}"
  })

  tags = var.tags
}

module "senzing_config" {
  source  = "terraform-aws-modules/ssm-parameter/aws"
  version = "~> 1.1"

  name        = "/${var.project}/${var.environment}/senzing"
  description = "Configuration for Senzing."
  tier        = "Intelligent-Tiering"
  type        = "SecureString"
  key_id      = aws_kms_key.container.arn
  secure_type = true
  value = jsonencode(yamldecode(templatefile("${path.module}/templates/senzing-config.yaml.tftpl", {
    database_host : module.database.cluster_endpoint
    database_username : jsondecode(data.aws_secretsmanager_secret_version.database.secret_string).username
    database_password : urlencode(jsondecode(data.aws_secretsmanager_secret_version.database.secret_string).password)
    senzing_license_base64 : " "
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

module "tools" {
  source     = "../ephemeral_service"
  depends_on = [aws_iam_policy.queue, aws_iam_policy.secrets]

  project                = var.project
  environment            = var.environment
  service                = "tools"
  image_tag              = var.image_tag
  image_tags_mutable     = var.image_tags_mutable
  container_key_arn      = aws_kms_key.container.arn
  logging_key_id         = var.logging_key_arn
  otel_ssm_parameter_arn = module.otel_config.ssm_parameter_arn
  execution_policies     = [aws_iam_policy.secrets.arn]
  task_policies          = [aws_iam_policy.queue.arn]
  dockerfile             = "Dockerfile.tools"
  docker_context         = "${path.module}/../../../"
  ephemeral_volumes = {
    senzing-home = "/home/senzing"
    # We need these to support ecs exec with a read-only root filesystem.
    aws-lib = "/var/lib/amazon"
    logs    = "/var/log"
  }

  environment_variables = {
    PGHOST : module.database.cluster_endpoint
    PGSSLMODE : "require"
    Q_URL : module.sqs.queue_url
    SENZING_DATASOURCES : "PEOPLE CUSTOMERS"
  }

  environment_secrets = {
    PGPASSWORD : "${module.database.cluster_master_user_secret[0].secret_arn}:password::"
    PGUSER : "${module.database.cluster_master_user_secret[0].secret_arn}:username::"
    SENZING_ENGINE_CONFIGURATION_JSON = module.senzing_config.ssm_parameter_arn
  }

  tags = var.tags
}

module "consumer" {
  source     = "../persistent_service"
  depends_on = [aws_iam_policy.queue, aws_iam_policy.secrets]

  project                = var.project
  environment            = var.environment
  service                = "consumer"
  image_tag              = var.image_tag
  image_tags_mutable     = var.image_tags_mutable
  container_key_arn      = aws_kms_key.container.arn
  logging_key_id         = var.logging_key_arn
  otel_ssm_parameter_arn = module.otel_config.ssm_parameter_arn
  execution_policies     = [aws_iam_policy.secrets.arn]
  task_policies          = [aws_iam_policy.queue.arn]
  security_groups        = [module.task_security_group.security_group_id]
  cluster_arn            = module.ecs.arn
  container_subnets      = var.container_subnets
  desired_containers     = var.consumer_container_count
  cpu                    = var.consumer_cpu
  memory                 = var.consumer_memory
  dockerfile             = "Dockerfile.consumer"
  docker_context         = "${path.module}/../../../"

  environment_variables = {
    Q_URL : module.sqs.queue_url
  }

  environment_secrets = {
    SENZING_ENGINE_CONFIGURATION_JSON = module.senzing_config.ssm_parameter_arn
  }

  tags = var.tags
}
