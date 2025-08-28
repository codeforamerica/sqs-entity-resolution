terraform {
  backend "s3" {
    bucket         = "${var.project}-${var.environment}-tfstate"
    key            = "${var.project}.tfstate"
    region         = var.region
    dynamodb_table = "${var.environment}.tfstate"
  }
}

resource "aws_servicecatalogappregistry_application" "application" {
  name        = "${var.project}-${var.environment}"
  description = "Senzing Entity Resolution on AWS using SQS and Fargate"
}

module "backend" {
  source = "github.com/codeforamerica/tofu-modules-aws-backend?ref=1.1.1"

  project     = var.project
  environment = var.environment

  tags = aws_servicecatalogappregistry_application.application.tags
}

module "logging" {
  source = "github.com/codeforamerica/tofu-modules-aws-logging?ref=2.1.0"

  project                  = var.project
  environment              = var.environment
  cloudwatch_log_retention = 1
  key_recovery_period      = 7

  tags = resource.aws_servicecatalogappregistry_application.application.application_tag
}

# TODO: Air gap this VPC from the internet.
module "vpc" {
  source = "github.com/codeforamerica/tofu-modules-aws-vpc?ref=1.1.2"

  project         = var.project
  environment     = var.environment
  cidr            = var.vpc_cidr
  logging_key_id  = module.logging.kms_key_arn
  private_subnets = var.vpc_private_subnet_cidrs

  # TODO: We don't need public subnets or a NAT gateway for an air gapped VPC.
  public_subnets     = var.vpc_public_subnet_cidrs
  single_nat_gateway = true

  tags = resource.aws_servicecatalogappregistry_application.application.application_tag
}
