output "export_bucket" {
  value       = module.s3.bucket
  description = "The name of the S3 bucket for exports."
}

output "queue_url" {
  value       = module.sqs.queue_url
  description = "The URL of the SQS queue."
}

output "task_security_group_id" {
  value       = module.task_security_group.security_group_id
  description = "The ID of the security group attached to the ECS tasks."
}
