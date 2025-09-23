output "consumer_image_push_commands" {
  value       = module.consumer.docker_push
  description = "Commands to push a Docker image to the consumer container repository."

}

output "tools_image_push_commands" {
  value       = module.tools.docker_push
  description = "Commands to push a Docker image to the consumer container repository."

}

output "export_bucket" {
  value       = module.s3.bucket
  description = "The name of the S3 bucket for exports."
}

output "queue_url" {
  value       = module.sqs.queue_url
  description = "The URL of the SQS queue."
}
