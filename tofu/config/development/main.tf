terraform {
  backend "s3" {
    bucket         = "sqs-senzing-development-tfstate"
    key            = "sqs-senzing.tfstate"
    region         = "us-east-1"
    dynamodb_table = "development.tfstate"
  }
}

module "backend" {
  source = "github.com/codeforamerica/tofu-modules-aws-backend?ref=1.1.1"

  project     = "sqs-senzing"
  environment = "development"
}

resource "aws_servicecatalogappregistry_application" "application" {
  name        = "sqs-senzing-development"
  description = "Senzing Entity Resolution on AWS using SQS and Fargate"
}

module "logging" {
  source = "github.com/codeforamerica/tofu-modules-aws-logging?ref=2.1.0"

  project                  = "sqs-senzing"
  environment              = "development"
  cloudwatch_log_retention = 1
  key_recovery_period      = 7

  tags = resource.aws_servicecatalogappregistry_application.application.application_tag
}

module "vpc" {
  source = "github.com/codeforamerica/tofu-modules-aws-vpc?ref=1.1.1"

  project            = "sqs-senzing"
  environment        = "development"
  cidr               = "10.0.56.0/22"
  single_nat_gateway = true
  logging_key_id     = module.logging.kms_key_arn

  private_subnets = ["10.0.58.0/26", "10.0.58.64/26", "10.0.58.128/26"]
  public_subnets = ["10.0.56.0/26", "10.0.56.64/26", "10.0.56.128/26"]

  tags = resource.aws_servicecatalogappregistry_application.application.application_tag
}
