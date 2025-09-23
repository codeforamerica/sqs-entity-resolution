locals {
  image_url      = module.ecr.repository_url
  prefix         = "${var.project}-${var.environment}-${var.service}"
  repository_arn = module.ecr.repository_arn
  stats_prefix   = var.stats_prefix != "" ? var.stats_prefix : "${var.project}/${var.service}"
  image_tag      = var.image_tag
}
