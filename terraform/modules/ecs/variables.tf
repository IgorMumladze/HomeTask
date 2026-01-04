variable "project_name" {
  description = "Project name for tagging/naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "create_cluster" {
  description = "Whether to create a new ECS cluster"
  type        = bool
  default     = true
}

variable "existing_cluster_name" {
  description = "Existing ECS cluster name (required if create_cluster = false)"
  type        = string
  default     = ""
}

variable "existing_cluster_arn" {
  description = "Existing ECS cluster ARN (optional if create_cluster = false)"
  type        = string
  default     = ""
}

variable "cluster_name_override" {
  description = "Override cluster base name (without -cluster). Leave empty to use project-environment."
  type        = string
  default     = ""
}

variable "name_suffix" {
  description = "Optional suffix to make ECS resources unique (e.g., api, worker)"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
}

variable "container_name" {
  description = "Primary container name"
  type        = string
}

variable "container_image" {
  description = "Container image (ECR URI)"
  type        = string
}

variable "container_port" {
  description = "Container port (for ALB target group when attached)"
  type        = number
}

variable "task_cpu" {
  description = "Fargate task CPU units"
  type        = string
}

variable "task_memory" {
  description = "Fargate task memory (MiB)"
  type        = string
}

variable "desired_count" {
  description = "ECS service desired task count"
  type        = number
}

variable "min_capacity" {
  description = "Autoscaling minimum capacity"
  type        = number
}

variable "max_capacity" {
  description = "Autoscaling maximum capacity"
  type        = number
}

variable "cpu_target_value" {
  description = "CPU utilization target for scaling"
  type        = number
  default     = 60
}

variable "memory_target_value" {
  description = "Memory utilization target for scaling"
  type        = number
  default     = 75
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the ECS tasks"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "attach_to_alb" {
  description = "Whether to attach the service to an ALB target group"
  type        = bool
  default     = true
}

variable "target_group_arn" {
  description = "Target group ARN for the service (required when attach_to_alb = true)"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
}

variable "container_insights_enabled" {
  description = "Enable Container Insights for the cluster"
  type        = bool
  default     = true
}

variable "environment_variables" {
  description = "Plaintext environment variables passed to the container"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secrets for the container (name -> SSM parameter ARN)"
  type        = map(string)
  default     = {}
}

variable "ecs_execution_role_arn" {
  description = "IAM execution role ARN"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "IAM task role ARN"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

