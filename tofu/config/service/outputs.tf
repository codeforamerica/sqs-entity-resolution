output "consumer_image_push_commands" {
  value       = module.system.consumer_image_push_commands
  description = "Commands to push a Docker image to the consumer container repository."
}

output "tools_image_push_commands" {
  value       = module.system.tools_image_push_commands
  description = "Commands to push a Docker image to the consumer container repository."
}

output "export_bucket" {
  value       = module.system.export_bucket
  description = "The name of the S3 bucket for exports."
}

output "queue_url" {
  value       = module.system.queue_url
  description = "The URL of the SQS queue."
}
