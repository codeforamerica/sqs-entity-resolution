variable "environment" {
  type        = string
  description = "Environment for the deployment."
  default     = "development"
}

variable "project" {
  type        = string
  description = "Project that these resources are supporting."
  default     = "sqs-senzing"
}
