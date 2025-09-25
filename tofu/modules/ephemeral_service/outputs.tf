output "container_name" {
  description = "Name of the container in the ECS task definition."
  value       = local.prefix
}

output "docker_push" {
  description = "Commands to push a Docker image to the container repository."
  value       = <<EOT
aws ecr get-login-password --region ${data.aws_region.current.region} | docker login --username AWS --password-stdin ${module.ecr.repository_registry_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com
docker build -t ${module.ecr.repository_name} --platform linux/amd64 -f ${var.dockerfile} .
docker tag ${module.ecr.repository_name}:${var.image_tag} ${module.ecr.repository_url}:latest
docker push ${module.ecr.repository_url}:latest
EOT
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition."
  value       = module.ecs_task.arn
}
