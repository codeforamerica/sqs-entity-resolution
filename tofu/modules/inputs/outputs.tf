output "values" {
  description = "Map of input names to their values."
  value       = { for k, v in data.aws_ssm_parameter.this : k => v.insecure_value }
}
