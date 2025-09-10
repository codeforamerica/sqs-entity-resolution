output "application_tags" {
  description = "The tags for the Service Catalog App Registry application."
  value       = aws_servicecatalogappregistry_application.application.application_tag
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
