variable "outputs" {
  type        = map(string)
  description = "Outputs to store in SSM Parameter Store."
  default     = {}
}

variable "prefix" {
  type        = string
  description = "Prefix to prepend to all resource names."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}
