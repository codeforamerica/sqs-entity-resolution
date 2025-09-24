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

module "deployment" {
  source = "../../modules/deployment"

  environment = var.environment
  oidc_arn    = var.repo_oidc_arn
  project     = var.project
  repository  = var.repository
  tags        = resource.aws_servicecatalogappregistry_application.application.application_tag
}

# Create deployment resources for any deployment environments specified.
module "deployment_environments" {
  source = "../../modules/deployment"
  for_each = toset(var.deployment_environments)

  environment = "development"
  system_environment = each.value
  oidc_arn    = var.repo_oidc_arn
  project     = var.project
  repository  = var.repository
  tags        = resource.aws_servicecatalogappregistry_application.application.application_tag
}

module "outputs" {
  source = "../../modules/outputs"

  prefix = "/${var.project}/${var.environment}"

  outputs = {
    "application/tag" = aws_servicecatalogappregistry_application.application.application_tag["awsApplication"]
    "logging/bucket"  = module.logging.bucket
    "logging/key"     = module.logging.kms_key_arn
  }
}
