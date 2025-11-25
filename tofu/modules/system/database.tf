resource "aws_kms_key" "database" {
  description             = "Database encryption key for Senzing."
  deletion_window_in_days = var.key_recovery_period
  enable_key_rotation     = true
  policy = jsonencode(yamldecode(templatefile("${path.module}/templates/database-key-policy.yaml.tftpl", {
    account_id : data.aws_caller_identity.identity.account_id,
    partition : data.aws_partition.current.partition,
    region : data.aws_region.current.region,
  })))

  tags = var.tags
}

resource "aws_kms_alias" "database" {
  name          = "alias/${var.project}/${var.environment}/database"
  target_key_id = aws_kms_key.database.id
}

# TODO: Configure AWS backup for longer retention.
module "database" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "9.15.0"

  name                                = "${local.prefix}-senzing"
  engine                              = "aurora-postgresql"
  engine_version                      = var.postgres_version
  storage_type                        = "aurora-iopt1"
  cluster_monitoring_interval         = 60
  vpc_id                              = var.vpc_id
  subnets                             = var.database_subnets
  create_db_subnet_group              = true
  iam_database_authentication_enabled = true
  copy_tags_to_snapshot               = true
  cloudwatch_log_group_kms_key_id     = var.logging_key_arn
  kms_key_id                          = aws_kms_key.database.arn
  backup_retention_period             = 35

  master_username                                        = var.database_admin_username
  manage_master_user_password_rotation                   = true
  master_user_password_rotation_automatically_after_days = var.database_password_rotation_frequency

  instances = {
    for i in range(var.database_instance_count) : i + 1 => {
      instance_class      = var.database_instance_type
      publicly_accessible = false
    }
  }

  security_group_rules = {
    # TODO: Use the security group ID of the containers instead of open to the
    #  full subnets.
    containers = {
      cidr_blocks = [for s in data.aws_subnet.container : s.cidr_block]
    }
  }

  apply_immediately   = var.apply_database_updates_immediately
  skip_final_snapshot = var.database_skip_final_snapshot
  deletion_protection = var.deletion_protection

  enabled_cloudwatch_logs_exports = ["iam-db-auth-error", "instance", "postgresql"]
  create_cloudwatch_log_group     = true

  cluster_performance_insights_enabled          = true
  cluster_performance_insights_retention_period = 31
  cluster_performance_insights_kms_key_id       = var.logging_key_arn

  tags = var.tags
}
