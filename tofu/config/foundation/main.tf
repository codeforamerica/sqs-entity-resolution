terraform {
  backend "s3" {
    bucket         = "${var.project}-${var.environment}-tfstate"
    key            = "foundation.tfstate"
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
  source = "github.com/codeforamerica/tofu-modules-aws-logging?ref=2.1.1"

  project             = var.project
  environment         = var.environment
  key_recovery_period = var.key_recovery_period

  tags = resource.aws_servicecatalogappregistry_application.application.application_tag
}
