variable "container_command" {
  type        = list(string)
  description = "Command to run in the container. Defaults to the image's CMD."
  default     = []
}

variable "container_port" {
  type        = number
  description = "Port that the container listens on."
  default     = 80
}

variable "cpu" {
  type        = number
  description = "CPU unit for this task."
  default     = 512
}

variable "environment" {
  type        = string
  description = "Environment for the deployment."
  default     = "dev"
}

variable "environment_secrets" {
  type        = map(string)
  description = "Secrets to be injected as environment variables on the container."
  default     = {}
}

variable "environment_variables" {
  type        = map(string)
  description = "Environment variables to set on the container."
  default     = {}
}

variable "execution_policies" {
  type        = list(string)
  description = "Additional policies to add to the task execution role."
  default     = []
}

variable "force_delete" {
  type        = bool
  description = "Force deletion of resources. If changing to true, be sure to apply before destroying."
  default     = false
}

variable "image_tag" {
  type        = string
  description = "Tag for the image to be deployed."
  default     = "latest"
}

variable "image_tags_mutable" {
  type        = bool
  description = "Whether image tags in the repository can be mutated."
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

variable "logging_key_id" {
  type        = string
  description = "KMS key ID for encrypting logs."
}

variable "memory" {
  type        = number
  description = "Memory for this task."
  default     = 1024
}

variable "otel_log_level" {
  type        = string
  description = "Log level for the OpenTelemetry collector."
  default     = "info"
}

variable "project" {
  type        = string
  description = "Project that these resources are supporting."
}

variable "service" {
  type        = string
  description = "Service that these resources are supporting. Example: 'api', 'web', 'worker'"
}

variable "stats_prefix" {
  type        = string
  description = "Prefix for statsd metrics. Defaults to `project`/`service`."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}

variable "task_policies" {
  type        = list(string)
  description = "Additional policies to add to the task role."
  default     = []
}

variable "untagged_image_retention" {
  type        = number
  description = "Retention period (after push) for untagged images, in days."
  default     = 14
}
