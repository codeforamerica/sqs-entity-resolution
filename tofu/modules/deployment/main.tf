resource "aws_iam_role" "deployment" {
  name = "${var.project}-${var.environment}-deployment-role"
  assume_role_policy = jsonencode(yamldecode(templatefile("${path.module}/templates/assume-policy.yaml.tftpl", {
    oidc_arn : var.oidc_arn
    repository : var.repository
  })))

  tags = var.tags
}

resource "aws_iam_role_policy" "deployment" {
  name = "${var.project}-${var.environment}-deployment-policy"
  role = aws_iam_role.deployment.name

  policy = jsonencode(yamldecode(templatefile("${path.module}/templates/iam-policy.yaml.tftpl", {
    account_id : data.aws_caller_identity.identity.account_id
    environment : var.environment
    region : data.aws_region.current.region
    partition : data.aws_partition.current.partition
    project : var.project
  })))
}
