output "container_name" {
  description = "Name of the container in the ECS task definition."
  value       = module.task.container_name
}

output "docker_push" {
  description = "Commands to push a Docker image to the container repository."
  value       = module.task.docker_push
}

output "service_name" {
  description = "Name of the ECS service."
  value       = module.service.name
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition."
  value       = module.task.task_definition_arn
}
