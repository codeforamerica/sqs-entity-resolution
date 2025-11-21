locals {
  image_tag = var.image_tag != null ? var.image_tag : sha256(timestamp())
  tags      = merge({ awsApplication : module.inputs.values["application/tag"] }, var.tags)
}
