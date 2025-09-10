terraform {
  backend "s3" {
    bucket         = "${var.project}-${var.environment}-tfstate"
    key            = "networking.tfstate"
    region         = var.region
    dynamodb_table = "${var.environment}.tfstate"
  }
}

# TODO: Air gap this VPC from the internet.
module "vpc" {
  source = "github.com/codeforamerica/tofu-modules-aws-vpc?ref=1.1.2"

  project         = var.project
  environment     = var.environment
  cidr            = var.vpc_cidr
  logging_key_id  = var.logging_key_arn
  private_subnets = var.vpc_private_subnet_cidrs

  # TODO: We don't need public subnets or a NAT gateway for an air gapped VPC.
  public_subnets     = var.vpc_public_subnet_cidrs
  single_nat_gateway = true

  tags = var.tags
}
