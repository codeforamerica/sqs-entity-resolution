#trivy:ignore:avd-aws-0104
module "task_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.1"

  name   = "${local.prefix}-task"
  vpc_id = var.vpc_id

  # TODO: Restrict egress to the VPC port 443, and the database security group
  #       port 5432.
  egress_cidr_blocks      = ["0.0.0.0/0"]
  egress_ipv6_cidr_blocks = ["::/0"]
  egress_rules            = ["all-all"]

  tags = var.tags
}

# TODO: Create a CMK for secrets
module "senzing_config" {
  source  = "terraform-aws-modules/ssm-parameter/aws"
  version = "~> 1.1"

  name        = "/${var.project}/${var.environment}/senzing"
  description = "Configuration for Senzing."
  tier        = "Intelligent-Tiering"
  type        = "SecureString"
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

  name                      = local.prefix
  capacity_providers        = ["FARGATE"]
  enable_container_insights = true

  tags = var.tags
}

module "tools" {
  source     = "../ephemeral_service"
  depends_on = [aws_iam_policy.secrets]

  environment        = var.environment
  project            = var.project
  service            = "tools"
  execution_policies = [aws_iam_policy.secrets.arn]
  image_tags_mutable = var.image_tags_mutable

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

  # TODO: Do we need this?
  logging_key_id = var.logging_key_arn

  tags = var.tags
}

module "consumer" {
  source     = "../fargate_service"
  depends_on = [aws_iam_policy.queue, aws_iam_policy.secrets]

  environment        = var.environment
  project            = var.project
  service            = "consumer"
  execution_policies = [aws_iam_policy.secrets.arn]
  task_policies      = [aws_iam_policy.queue.arn]
  container_subnets  = var.container_subnets
  logging_key_id     = var.logging_key_arn
  cluster_arn        = module.ecs.arn
  security_groups    = [module.task_security_group.security_group_id]
  desired_containers = var.consumer_container_count
  image_tags_mutable = var.image_tags_mutable

  environment_variables = {
    Q_URL : module.sqs.queue_url
  }

  environment_secrets = {
    SENZING_ENGINE_CONFIGURATION_JSON = module.senzing_config.ssm_parameter_arn
  }

  tags = var.tags
}

data "aws_secretsmanager_secret_version" "database" {
  secret_id = module.database.cluster_master_user_secret[0].secret_arn
}
