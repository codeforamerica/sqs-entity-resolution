data "aws_ssm_parameter" "this" {
  for_each = toset(var.inputs)

  name = join("/", compact([var.prefix, each.value]))
}
