module "otel_config" {
  source  = "terraform-aws-modules/ssm-parameter/aws"
  version = "~> 1.1"

  name        = "/${var.project}/${var.environment}/${var.service}/otel"
  description = "Configuration for the OpenTelemetry collector."
  tier        = "Intelligent-Tiering"
  value = templatefile("${path.module}/templates/aws-otel-config.yaml.tftpl", {
    app_namespace = local.stats_prefix
  })

  tags = var.tags
}
