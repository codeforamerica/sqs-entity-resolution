# Create a private repository for the OTEL collector image. This image is
# available publicly, but pulling from a public repository requires internet
# access which may not be available in all VPC configurations. We'll copy the
# image to a private repository to allow pulling through a VPC endpoint.
module "otel_ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 3.0"

  repository_name                 = "${local.prefix}-otel"
  repository_image_scan_on_push   = true
  repository_encryption_type      = "KMS"
  repository_force_delete         = !var.deletion_protection
  repository_image_tag_mutability = var.image_tags_mutable ? "MUTABLE" : "IMMUTABLE"
  repository_kms_key              = aws_kms_key.container.arn

  repository_lifecycle_policy = jsonencode(yamldecode(templatefile(
    "${path.module}/../ephemeral_service/templates/repository-lifecycle.yaml.tftpl", {
      untagged_image_retention : var.untagged_image_retention
    }
  )))

  tags = var.tags
}

resource "aws_ssm_parameter" "otel_config" {
  name        = "/${var.project}/${var.environment}/otel"
  description = "Configuration for the OpenTelemetry collector."
  tier        = "Intelligent-Tiering"
  type        = "SecureString"
  overwrite   = true
  key_id      = aws_kms_key.container.arn

  value = templatefile("${path.module}/templates/aws-otel-config.yaml.tftpl", {
    app_namespace = "${var.project}/${var.environment}"
  })

  tags = var.tags
}

data "docker_registry_image" "otel" {
  name = "public.ecr.aws/aws-observability/aws-otel-collector:${var.otel_version}"
}

resource "docker_image" "otel" {
  name          = data.docker_registry_image.otel.name
  platform      = "linux/amd64"
  pull_triggers = [data.docker_registry_image.otel.sha256_digest]
}

resource "docker_tag" "otel" {
  source_image = docker_image.otel.name
  target_image = "${module.otel_ecr.repository_url}:${var.otel_version}"
  tag_triggers = [data.docker_registry_image.otel.sha256_digest]
}

resource "docker_registry_image" "otel" {
  depends_on = [module.otel_ecr, docker_tag.otel]

  name          = docker_tag.otel.target_image
  keep_remotely = true

  auth_config {
    address  = data.aws_ecr_authorization_token.otel.proxy_endpoint
    password = data.aws_ecr_authorization_token.otel.password
    username = data.aws_ecr_authorization_token.otel.user_name
  }

  triggers = {
    digest : data.docker_registry_image.otel.sha256_digest
  }

  lifecycle {
    ignore_changes = [auth_config]
  }
}
