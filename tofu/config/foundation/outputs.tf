output "application_arn" {
  description = "ARN of the Service Catalog App Registry application."
  value       = aws_servicecatalogappregistry_application.application.arn
}

output "deployment_role_arn" {
  value       = module.deployment.role_arn
  description = "The ARN of the deployment role for system components."
}

output "environment_deployment_roles" {
  value       = { for env, mod in module.deployment_environments : env => mod.role_arn }
  description = "The ARN of the deployment role for the dev-cdii environment."
}

output "logging_bucket" {
  value       = module.logging.bucket
  description = "The name of the S3 bucket for logging."
}

output "logging_key_arn" {
  value       = module.logging.kms_key_arn
  description = "The ARN of the KMS key for logging."
}

output "state_bucket" {
  value       = module.backend.bucket
  description = "The name of the S3 bucket for infrastructure state files."
}
