variable "project_name" {
  description = "Project name for tagging/naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID to ensure global uniqueness of the bucket"
  type        = string
}

variable "bucket_suffix" {
  description = "Optional suffix to make bucket name unique"
  type        = string
  default     = ""
}

variable "versioning_enabled" {
  description = "Enable S3 versioning"
  type        = bool
  default     = true
}

variable "enable_public_access_block" {
  description = "Create S3 public access block (set false if blocked by org policies)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

