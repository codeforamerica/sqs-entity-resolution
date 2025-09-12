variable "environment" {
  type        = string
  description = "Environment for the deployment."
  default     = "development"
}

variable "key_recovery_period" {
  type        = number
  default     = 30
  description = "Recovery period for deleted KMS keys in days. Must be between 7 and 30."

  validation {
    condition     = var.key_recovery_period > 6 && var.key_recovery_period < 31
    error_message = "Recovery period must be between 7 and 30."
  }
}

variable "program" {
  type        = string
  description = "Program the project belongs to."
  default     = null
}

variable "project" {
  type        = string
  description = "Project that these resources are supporting."
  default     = "sqs-senzing"
}

variable "region" {
  type        = string
  description = "AWS region where resources should be deployed."
  default     = "us-west-1"
}

variable "repository" {
  type        = string
  description = "GitHub repository in the format 'owner/repo'."
  default     = "codeforamerica/sqs-entity-resolution"
}

variable "repo_oidc_arn" {
  type        = string
  description = "ARN of the OpenID Connect provider for the GitHub repository."
}
