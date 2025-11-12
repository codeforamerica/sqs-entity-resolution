terraform {
  backend "s3" {
    bucket         = "${var.project}-${var.environment}-tfstate"
    key            = "service.tfstate"
    region         = var.region
    dynamodb_table = "${var.environment}.tfstate"
  }
}

module "inputs" {
  source = "github.com/codeforamerica/tofu-modules-aws-ssm-inputs?ref=1.0.0"

  prefix = "/${var.project}/${var.environment}"

  inputs = ["application/tag", "logging/bucket", "logging/key", "vpc/id", "vpc/private_subnets"]
}

module "system" {
  source = "../../modules/system"

  environment            = var.environment
  project                = var.project
  export_expiration      = var.export_expiration
  key_recovery_period    = var.key_recovery_period
  logging_bucket         = module.inputs.values["logging/bucket"]
  logging_key_arn        = module.inputs.values["logging/key"]
  log_level              = var.log_level
  tags                   = merge({ awsApplication : module.inputs.values["application/tag"] }, var.tags)
  vpc_id                 = module.inputs.values["vpc/id"]
  queue_empty_threshold  = var.queue_empty_threshold
  senzing_license_base64 = var.senzing_license_base64

  database_subnets                   = split(",", module.inputs.values["vpc/private_subnets"])
  apply_database_updates_immediately = var.apply_database_updates_immediately
  database_instance_count            = var.database_instance_count
  database_skip_final_snapshot       = var.database_skip_final_snapshot
  deletion_protection                = var.deletion_protection
  image_tag                          = local.image_tag
  image_tags_mutable                 = var.image_tags_mutable

  container_subnets          = split(",", module.inputs.values["vpc/private_subnets"])
  otel_version               = var.otel_version
  consumer_container_count   = var.consumer_container_count
  consumer_container_max     = var.consumer_container_max
  consumer_cpu               = var.consumer_cpu
  consumer_memory            = var.consumer_memory
  consumer_message_threshold = var.consumer_message_threshold
  redoer_container_count     = var.redoer_container_count
  redoer_cpu                 = var.redoer_cpu
  redoer_memory              = var.redoer_memory
}
