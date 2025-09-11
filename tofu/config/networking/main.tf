terraform {
  backend "s3" {
    bucket         = "${var.project}-${var.environment}-tfstate"
    key            = "networking.tfstate"
    region         = var.region
    dynamodb_table = "${var.environment}.tfstate"
  }
}

module "inputs" {
  source = "../../modules/inputs"

  prefix = "/${var.project}/${var.environment}"

  inputs = ["application/tag", "logging/key"]
}

# TODO: Air gap this VPC from the internet.
module "vpc" {
  source = "github.com/codeforamerica/tofu-modules-aws-vpc?ref=1.1.2"

  project         = var.project
  environment     = var.environment
  cidr            = var.vpc_cidr
  logging_key_id  = module.inputs.values["logging/key"]
  private_subnets = var.vpc_private_subnet_cidrs

  # TODO: We don't need public subnets or a NAT gateway for an air gapped VPC.
  public_subnets     = var.vpc_public_subnet_cidrs
  single_nat_gateway = true

  tags = merge({ awsApplication : module.inputs.values["application/tag"] }, var.tags)
}

module "outputs" {
  source = "../../modules/outputs"

  prefix = "/${var.project}/${var.environment}"

  outputs = {
    "vpc/id"              = module.vpc.vpc_id
    "vpc/private_subnets" = join(",", module.vpc.private_subnets)
    "vpc/public_subnets"  = join(",", module.vpc.public_subnets)
  }
}
