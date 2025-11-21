provider "aws" {
  region = var.region

  default_tags {
    tags = {
      application = "${var.project}-${var.environment}"
      environment = var.environment
      program     = var.program
      project     = var.project
    }
  }
}
