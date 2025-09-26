terraform {
  backend "s3" {
    bucket         = "${var.project}-${var.environment}-tfstate"
    key            = "service.tfstate"
    region         = var.region
    dynamodb_table = "${var.environment}.tfstate"
  }
}

module "inputs" {
  source = "../../modules/inputs"

  prefix = "/${var.project}/${var.environment}"

  inputs = ["application/tag", "logging/bucket", "logging/key", "vpc/id", "vpc/private_subnets"]
}

module "system" {
  source = "../../modules/system"

  environment         = var.environment
  project             = var.project
  export_expiration   = var.export_expiration
  key_recovery_period = var.key_recovery_period
  logging_bucket      = module.inputs.values["logging/bucket"]
  logging_key_arn     = module.inputs.values["logging/key"]
  tags                = merge({ awsApplication : module.inputs.values["application/tag"] }, var.tags)
  vpc_id              = module.inputs.values["vpc/id"]
  database_subnets    = split(",", module.inputs.values["vpc/private_subnets"])
  container_subnets   = split(",", module.inputs.values["vpc/private_subnets"])

  apply_database_updates_immediately = var.apply_database_updates_immediately
  database_skip_final_snapshot       = var.database_skip_final_snapshot
  deletion_protection                = var.deletion_protection
  image_tag                          = var.image_tag != null ? var.image_tag : sha256(timestamp())
  image_tags_mutable                 = var.image_tags_mutable

  consumer_container_count = var.consumer_container_count
  consumer_cpu             = var.consumer_cpu
  consumer_memory          = var.consumer_memory
}
