variable "cluster_name" {
  type        = string
  description = "Name of the ECS cluster to deploy to."
}

variable "container_command" {
  type        = list(string)
  description = "Command to run in the container. Defaults to the image's CMD."
  default     = []
}

variable "container_key_arn" {
  type        = string
  description = "ARN of the KMS key to use for encrypting the container image repository."
}

variable "container_subnets" {
  type        = list(string)
  description = "The IDs of the subnets in which the container resources should be deployed."
}

variable "cpu" {
  type        = number
  description = "Number of virtual CPUs to allocate to the container."
  default     = 1
}

variable "desired_containers" {
  type        = number
  description = "Desired number of running containers for the service."
  default     = 1
}

variable "docker_context" {
  type        = string
  description = "Path to the Docker build context."
  default     = null
}

variable "dockerfile" {
  type        = string
  description = "Path to the Dockerfile to use for building the image."
  default     = "Dockerfile"
}

variable "enable_execute_command" {
  type        = bool
  description = "Whether to enable ECS Exec on the service."
  default     = false
}

variable "environment" {
  type        = string
  description = "Environment for the deployment."
  default     = "development"
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

variable "ephemeral_volumes" {
  type        = map(string)
  description = "Map of ephemeral volume names to mount paths."
  default = {
    logs         = "/var/log"
    senzing-home = "/home/senzing"
  }
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

variable "logging_key_id" {
  type        = string
  description = "KMS key ID for encrypting logs."
}

variable "max_containers" {
  type        = number
  description = "Maximum number of running containers for the service."
  default     = 10
}

variable "memory" {
  type        = number
  description = "Memory for this task."
  default     = 4096
}

variable "otel_ssm_parameter_arn" {
  type        = string
  description = "ARN of the SSM parameter containing the OpenTelemetry collector configuration."
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

variable "scale_down_policy" {
  type = object({
    enabled = optional(bool, true)
  })
  description = "Configuration for scaling down the service. If not provided, no scaling policy will be created."
  default     = { enabled : false }
}

variable "scale_up_policy" {
  type = object({
    enabled = optional(bool, true)
    start   = optional(number, 1)
    step    = optional(number, 250000)
  })
  description = "Configuration for scaling up the service. If not provided, no scaling policy will be created."
  default     = { enabled : false }
}

variable "security_groups" {
  type        = list(string)
  description = "The IDs of the security groups to associate with the container resources."
  default     = []
}

variable "service" {
  type        = string
  description = "Service that these resources are supporting. Example: 'api', 'web', 'worker'"
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
