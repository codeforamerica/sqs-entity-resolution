resource "aws_cloudwatch_dashboard" "this" {
  for_each = toset(["consumer", "exporter", "redoer"])

  dashboard_name = "${local.prefix}-${each.key}"
  dashboard_body = templatefile("${path.module}/templates/${each.key}.json.tftpl", {
    project        = var.project
    environment    = var.environment
    region         = data.aws_region.current.region
  })
}
