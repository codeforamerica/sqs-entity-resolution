variable "apply_database_updates_immediately" {
  type        = bool
  description = "Whether to apply database updates immediately. May result in downtime."
  default     = false
}

variable "consumer_container_count" {
  type        = number
  description = "Desired number of consumer containers to run."
  default     = 1
}

variable "consumer_container_max" {
  type        = number
  description = "Maximum number of consumer containers to run."
  default     = 10
}

variable "consumer_cpu" {
  type        = number
  description = "Number of virtual CPUs to allocate to each consumer container."
  default     = 1
}

variable "consumer_memory" {
  type        = number
  description = "Amount of memory (in MiB) to allocate to each consumer container."
  default     = 4096
}

variable "consumer_message_threshold" {
  type        = number
  description = "Number of messages in the SQS queue that will trigger scaling up the number of consumer containers."
  default     = 250000
}

variable "database_instance_count" {
  type        = number
  description = "Number of instances in the database cluster."
  default     = 1

  validation {
    condition     = var.database_instance_count >= 0 && var.database_instance_count < 17
    error_message = "Database instance count must be between 0 and 16."
  }
}

variable "database_skip_final_snapshot" {
  type        = bool
  description = "Whether to skip the final snapshot when the database cluster is deleted."
  default     = false
}

variable "deletion_protection" {
  type        = bool
  description = "Whether to enable deletion protection on the database cluster. Must be disabled and applied before resources can be deleted."
  default     = true
}

variable "environment" {
  type        = string
  description = "Environment for the deployment."
  default     = "development"
}

variable "export_expiration" {
  type        = number
  default     = 365
  description = "Number of days before export files expire."
}

variable "image_tag" {
  type        = string
  description = "Tag for the docker images, will be used for all images. Leave empty to have a new tag generated on each run."
  default     = null
}

variable "image_tags_mutable" {
  type        = bool
  description = "Whether to allow image tags to be mutable."
  default     = false
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

variable "log_level" {
  type        = string
  description = "Log level for all containers."
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.log_level)
    error_message = "Valid log levels are: DEBUG, INFO, WARNING, ERROR, CRITICAL."
  }
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

variable "queue_empty_threshold" {
  type        = number
  description = "Number of minutes that the SQS queue must have zero messages before we consider it empty."
  default     = 15
}

variable "redoer_container_count" {
  type        = number
  description = "Desired number of redoer containers to run."
  default     = 1
}

variable "redoer_cpu" {
  type        = number
  description = "Number of virtual CPUs to allocate to each redoer container."
  default     = 1
}

variable "redoer_memory" {
  type        = number
  description = "Amount of memory (in MiB) to allocate to each redoer container."
  default     = 4096
}

variable "region" {
  type        = string
  description = "AWS region where resources should be deployed."
  default     = "us-west-1"
}

variable "senzing_license_base64" {
  type        = string
  description = "Base64 encoded Senzing license."
  default     = null
  sensitive   = true
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}
