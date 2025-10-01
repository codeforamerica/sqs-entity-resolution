output "container_subnets" {
  value       = split(",", module.inputs.values["vpc/private_subnets"])
  description = "The IDs of the subnets in which the container resources will be deployed."
}

output "export_bucket" {
  value       = module.system.export_bucket
  description = "The name of the S3 bucket for exports."
}

output "image_tag" {
  value       = local.image_tag
  description = "The tag of the container image used for the ECS tasks."
}

output "queue_url" {
  value       = module.system.queue_url
  description = "The URL of the SQS queue."
}

output "task_security_group_id" {
  value       = module.system.task_security_group_id
  description = "The ID of the security group attached to the ECS tasks."
}
