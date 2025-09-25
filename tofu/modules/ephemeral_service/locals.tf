locals {
  prefix = join("-", compact([var.project, var.environment, var.service]))
}
