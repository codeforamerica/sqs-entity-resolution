variable "apply_database_updates_immediately" {
  type        = bool
  description = "Whether to apply database updates immediately. May result in downtime."
  default     = false
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
  description = "Tags to apply to all resources."
  default     = {}
}
