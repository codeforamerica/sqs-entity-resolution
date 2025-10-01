locals {
  image_tag = var.image_tag != null ? var.image_tag : sha256(timestamp())
}
