output "export_bucket" {
  value       = module.system.export_bucket
  description = "The name of the S3 bucket for exports."
}

output "queue_url" {
  value       = module.system.queue_url
  description = "The URL of the SQS queue."
}
