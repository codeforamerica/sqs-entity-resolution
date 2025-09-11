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

  inputs = ["application/tag", "logging/bucket"]
}

module "system" {
  source = "../../modules/system"

  environment         = var.environment
  project             = var.project
  export_expiration   = var.export_expiration
  key_recovery_period = var.key_recovery_period
  logging_bucket      = module.inputs.values["logging/bucket"]
  tags                = merge({ awsApplication : module.inputs.values["application/tag"] }, var.tags)
}
