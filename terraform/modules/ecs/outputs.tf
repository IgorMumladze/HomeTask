output "cluster_name" {
  description = "ECS cluster name"
  value       = local.cluster_name
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = local.cluster_arn
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.this.name
}

output "service_arn" {
  description = "ECS service ARN"
  value       = aws_ecs_service.this.arn
}

output "task_definition_arn" {
  description = "Task definition ARN"
  value       = aws_ecs_task_definition.this.arn
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.this.name
}

