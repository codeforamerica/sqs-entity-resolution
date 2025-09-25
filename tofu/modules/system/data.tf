data "aws_caller_identity" "identity" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_secretsmanager_secret_version" "database" {
  secret_id = module.database.cluster_master_user_secret[0].secret_arn
}

data "aws_subnet" "container" {
  for_each = toset(var.container_subnets)
  id       = each.value
}
