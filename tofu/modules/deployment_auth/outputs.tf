output "iam_role" {
  description = "The name of the IAM role created for deployments."
  value       = aws_iam_role.deployment.name
}
