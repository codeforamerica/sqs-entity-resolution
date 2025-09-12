output "role_arn" {
  description = "ARN of the IAM role created for deployments."
  value       = aws_iam_role.deployment.arn
}

output "role_name" {
  description = "Name of the IAM role created for deployments."
  value       = aws_iam_role.deployment.name
}
