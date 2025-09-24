locals {
  system_environment = coalesce(var.system_environment, var.environment)
}
