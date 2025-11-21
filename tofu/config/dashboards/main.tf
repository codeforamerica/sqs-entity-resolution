terraform {
  backend "s3" {
    bucket         = "${var.project}-${var.environment}-tfstate"
    key            = "dashboards.tfstate"
    region         = var.region
    dynamodb_table = "${var.environment}.tfstate"
  }
}

module "dashboards" {
  source = "../../modules/dashboards"

  environment = var.environment
  project     = var.project
}
