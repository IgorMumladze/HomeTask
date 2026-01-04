variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "availability_zones" {
  description = "AZs list"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs"
  type        = list(string)
}

variable "s3_versioning_enabled" {
  description = "Enable S3 versioning"
  type        = bool
}

variable "bucket_suffix" {
  description = "Optional suffix to ensure S3 bucket uniqueness"
  type        = string
  default     = ""
}

variable "enable_public_access_block" {
  description = "Create S3 public access block (set false if org blocks it)"
  type        = bool
  default     = true
}

variable "api_container_port" {
  description = "API container port"
  type        = number
}

variable "api_ecs_task_cpu" {
  description = "API task CPU units"
  type        = string
}

variable "api_ecs_task_memory" {
  description = "API task memory (MiB)"
  type        = string
}

variable "api_ecs_desired_count" {
  description = "API desired task count"
  type        = number
}

variable "api_ecs_min_capacity" {
  description = "API min autoscaling capacity"
  type        = number
}

variable "api_ecs_max_capacity" {
  description = "API max autoscaling capacity"
  type        = number
}

variable "api_ecs_cpu_target_value" {
  description = "API CPU target for scaling"
  type        = number
  default     = 60
}

variable "api_ecs_memory_target_value" {
  description = "API memory target for scaling"
  type        = number
  default     = 75
}

variable "api_container_insights_enabled" {
  description = "Enable Container Insights for API"
  type        = bool
}

variable "api_log_retention_days" {
  description = "API log retention days"
  type        = number
}

variable "worker_container_port" {
  description = "Worker container port (not exposed)"
  type        = number
  default     = 8080
}

variable "worker_ecs_task_cpu" {
  description = "Worker task CPU units"
  type        = string
}

variable "worker_ecs_task_memory" {
  description = "Worker task memory (MiB)"
  type        = string
}

variable "worker_ecs_desired_count" {
  description = "Worker desired task count"
  type        = number
}

variable "worker_ecs_min_capacity" {
  description = "Worker min autoscaling capacity"
  type        = number
}

variable "worker_ecs_max_capacity" {
  description = "Worker max autoscaling capacity"
  type        = number
}

variable "worker_ecs_cpu_target_value" {
  description = "Worker CPU target for scaling"
  type        = number
  default     = 60
}

variable "worker_ecs_memory_target_value" {
  description = "Worker memory target for scaling"
  type        = number
  default     = 75
}

variable "worker_container_insights_enabled" {
  description = "Enable Container Insights for worker"
  type        = bool
}

variable "worker_log_retention_days" {
  description = "Worker log retention days"
  type        = number
}

variable "api_image_tag" {
  description = "Tag for the API image (built from ECR repo URL + tag)"
  type        = string
  default     = "latest"
}

variable "worker_image_tag" {
  description = "Tag for the worker image (built from ECR repo URL + tag)"
  type        = string
  default     = "latest"
}

variable "queue_delay_seconds" {
  description = "SQS delay seconds"
  type        = number
  default     = 0
}

variable "queue_message_retention_seconds" {
  description = "SQS message retention"
  type        = number
  default     = 345600
}

variable "queue_visibility_timeout_seconds" {
  description = "SQS visibility timeout"
  type        = number
  default     = 30
}

variable "queue_max_receive_count" {
  description = "DLQ max receive count"
  type        = number
  default     = 5
}

variable "alb_deletion_protection" {
  description = "Enable ALB deletion protection"
  type        = bool
}

variable "enable_https" {
  description = "Enable HTTPS listener"
  type        = bool
}

variable "ssl_certificate_arn" {
  description = "ACM cert ARN for HTTPS"
  type        = string
  default     = ""

  validation {
    condition = (
      var.ssl_certificate_arn == "" ||
      can(regex("^arn:aws:acm:.*", var.ssl_certificate_arn))
    )
    error_message = "If provided, ssl_certificate_arn must start with arn:aws:acm: (or leave empty when HTTPS is disabled)."
  }
}

variable "health_check_path" {
  description = "ALB target group health check path"
  type        = string
  default     = "/"
}

variable "environment_variables" {
  description = "Additional environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Additional secrets map name -> SSM ARN"
  type        = map(string)
  default     = {}
}

variable "api_token" {
  description = "API token stored in SSM"
  type        = string
  sensitive   = true
}

variable "ecr_repositories" {
  description = "ECR repositories to create (suffix names); repo will be <project>-<env>-<suffix>"
  type        = list(string)
  default     = ["api", "worker"]
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

