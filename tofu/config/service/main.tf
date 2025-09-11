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

  inputs = ["application/arn", "logging/bucket", "vpc/id", "vpc/private_subnets"]
}

module "system" {
  source = "../../modules/system"

  environment         = var.environment
  project             = var.project
  export_expiration   = var.export_expiration
  key_recovery_period = var.key_recovery_period
  logging_bucket      = module.inputs.values["logging/bucket"]
  vpc_id              = module.inputs.values["vpc/id"]
  database_subnets    = split(",", module.inputs.values["vpc/private_subnets"])
  tags                = merge({ awsApplication : module.inputs.values["application/arn"] }, var.tags)
}
