resource "docker_buildx_builder" "this" {
  name   = "${local.prefix}-builder"
  driver = "docker-container"
}

resource "docker_image" "container" {
  name = "${module.ecr.repository_url}:${var.image_tag}"

  build {
    builder    = docker_buildx_builder.this.name
    context    = var.docker_context
    dockerfile = "${var.docker_context}/${var.dockerfile}"
    platform   = "linux/amd64"

    cache_from = ["type=registry,ref=${module.ecr.repository_url}"]
    cache_to   = ["type=registry,ref=${module.ecr.repository_url},mode=max,image-manifest=true"]

    tag = [
      "${local.prefix}:${var.image_tag}",
      "${module.ecr.repository_url}:${var.image_tag}"
    ]

    auth_config {
      host_name = data.aws_ecr_authorization_token.token.proxy_endpoint
      password  = data.aws_ecr_authorization_token.token.password
      user_name = data.aws_ecr_authorization_token.token.user_name
    }
  }

  triggers = {
    image_tage = var.image_tag
  }
}

data "aws_ecr_authorization_token" "token" {
  registry_id = module.ecr.repository_registry_id
}

resource "docker_registry_image" "container" {
  depends_on = [module.ecr]

  name          = docker_image.container.name
  keep_remotely = true

  auth_config {
    address  = data.aws_ecr_authorization_token.token.proxy_endpoint
    password = data.aws_ecr_authorization_token.token.password
    username = data.aws_ecr_authorization_token.token.user_name
  }

  triggers = {
    sha = docker_image.container.id
  }

  lifecycle {
    ignore_changes = [auth_config]
  }
}
