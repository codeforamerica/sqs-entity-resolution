variable "environment" {
  type        = string
  description = "Environment for the deployment."
  default     = "development"
}

variable "program" {
  type        = string
  description = "Program the application belongs to."
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
