terraform {
  backend "s3" {
    bucket         = "${var.project}-${var.environment}-tfstate"
    key            = "service.tfstate"
    region         = var.region
    dynamodb_table = "${var.environment}.tfstate"
  }
}

module "system" {
  source = "../../modules/system"

  environment         = var.environment
  project             = var.project
  export_expiration   = var.export_expiration
  key_recovery_period = var.key_recovery_period
  logging_bucket      = var.logging_bucket
  vpc_id              = var.vpc_id
  database_subnets    = var.database_subnet_ids
  tags                = var.tags
}
