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
