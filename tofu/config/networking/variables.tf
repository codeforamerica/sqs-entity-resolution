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

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources."
  default     = {}
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
}

variable "vpc_private_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for private subnets."
}

variable "vpc_public_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for public subnets."
}
