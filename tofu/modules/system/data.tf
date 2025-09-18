data "aws_caller_identity" "identity" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_subnet" "container" {
  for_each = toset(var.container_subnets)
  id       = each.value
}
