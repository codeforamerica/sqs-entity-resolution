resource "aws_ssm_parameter" "this" {
  for_each = var.outputs

  name  = join("/", compact([var.prefix, each.key]))
  type  = "String"
  value = each.value

  tags = var.tags
}
