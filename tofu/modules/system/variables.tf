variable "apply_database_updates_immediately" {
  type        = bool
  description = "Whether to apply database updates immediately. May result in downtime."
  default     = false
}

variable "container_subnets" {
  description = "The IDs of the subnets in which the container resources should be deployed."
  type        = list(string)
}

variable "database_instance_count" {
  type        = number
  description = "Number of instances in the database cluster."
  default     = 1

  validation {
    condition     = var.database_instance_count > 0 && var.database_instance_count < 17
    error_message = "Database instance count must be between 1 and 16."
  }
}

variable "database_instance_type" {
  type        = string
  description = "Instance type to use for the database instances."
  default     = "db.t4g.medium"
}

variable "database_skip_final_snapshot" {
  type        = bool
  description = "Whether to skip the final snapshot when the database cluster is deleted."
  default     = false
}

variable "database_subnets" {
  description = "The IDs of the subnets in which the database resources should be deployed."
  type        = list(string)
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

variable "export_lock_age" {
  type        = number
  description = "Age (based on the lock period) of an object before the lock is removed."
  default     = 30
}

variable "export_lock_mode" {
  type        = string
  description = "Object lock mode for the export bucket."
  default     = "GOVERNANCE"

  validation {
    condition     = contains(["COMPLIANCE", "GOVERNANCE", "DISABLED"], var.export_lock_mode)
    error_message = "Valid object lock modes are: COMPLIANCE, GOVERNANCE, or DISABLED."
  }
}

variable "export_lock_period" {
  type        = string
  description = "Period for which objects are locked. Valid values are days or years."
  default     = "days"

  validation {
    condition     = contains(["days", "years"], var.export_lock_period)
    error_message = "Valid object lock periods are: days, years."
  }
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

variable "logging_bucket" {
  type        = string
  description = "S3 bucket to use for log collection."
}

variable "logging_key_arn" {
  type        = string
  description = "ARN of the KMS key to use for log encryption."
}

variable "postgres_version" {
  type        = string
  description = "Version of PostgreSQL to use for the database cluster."
  default     = "17"
}

variable "project" {
  type        = string
  description = "Project that these resources are supporting."
  default     = "sqs-senzing"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources."
  default     = {}
}

variable "vpc_id" {
  description = "The ID of the VPC in which resources should be deployed."
  type        = string
}
