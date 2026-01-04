variable "project_name" {
  description = "Project name for tagging/naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "delay_seconds" {
  description = "Default queue delay seconds"
  type        = number
  default     = 0
}

variable "message_retention_seconds" {
  description = "How long messages are retained"
  type        = number
  default     = 345600
}

variable "visibility_timeout_seconds" {
  description = "Visibility timeout"
  type        = number
  default     = 30
}

variable "max_receive_count" {
  description = "Max receive count before moving to DLQ"
  type        = number
  default     = 5
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

