resource "aws_iam_role" "deployment" {
  name = "${var.project}-${local.system_environment}-deployment-role"
  assume_role_policy = jsonencode(yamldecode(templatefile("${path.module}/templates/assume-policy.yaml.tftpl", {
    oidc_arn : var.oidc_arn
    repository : var.repository
  })))

  tags = var.tags
}

resource "aws_iam_role_policy" "deployment" {
  name = "${var.project}-${local.system_environment}-deployment-policy"
  role = aws_iam_role.deployment.name

  policy = jsonencode(yamldecode(templatefile("${path.module}/templates/iam-policy.yaml.tftpl", {
    account_id : data.aws_caller_identity.identity.account_id
    environment : var.environment
    region : data.aws_region.current.region
    partition : data.aws_partition.current.partition
    project : var.project
    system_environment : local.system_environment
  })))
}

# Create a separate policy for state access to avoid size limits on the main
# policy.
resource "aws_iam_policy" "state" {
  name        = "${var.project}-${local.system_environment}-state-policy"
  description = "Allow access to S3 bucket and DynamoDB table for Terraform state."

  policy = jsonencode(yamldecode(templatefile("${path.module}/templates/state-policy.yaml.tftpl", {
    account_id : data.aws_caller_identity.identity.account_id
    environment : var.environment
    region : data.aws_region.current.region
    partition : data.aws_partition.current.partition
    project : var.project
  })))

  tags = var.tags
}

resource "aws_iam_role_policy_attachments_exclusive" "attach" {
  role_name   = aws_iam_role.deployment.name
  policy_arns = [aws_iam_policy.state.arn]
}
