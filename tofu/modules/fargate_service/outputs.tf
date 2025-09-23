output "docker_push" {
  description = "Commands to push a Docker image to the container repository."
  value       = <<EOT
aws ecr get-login-password --region ${data.aws_region.current.region} | docker login --username AWS --password-stdin ${module.ecr.repository_registry_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com
docker build -t ${module.ecr.repository_name} --platform linux/amd64 -f Dockerfile .
docker tag ${module.ecr.repository_name}:${var.image_tag} ${local.image_url}:latest
docker push ${local.image_url}:latest
EOT
}
