variable "environment" {
  type        = string
  description = "Environment for the deployment."
  default     = "development"
}

variable "oidc_arn" {
  type        = string
  description = "ARN of the OpenID Connect provider for the GitHub repository."
}

variable "project" {
  type        = string
  description = "Project that these resources are supporting."
  default     = "sqs-senzing"
}

variable "repository" {
  type        = string
  description = "GitHub repository in the format 'owner/repo'."
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources."
  default     = {}
}
