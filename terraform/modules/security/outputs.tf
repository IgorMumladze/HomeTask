output "ecs_execution_role_arn" {
  description = "ECS execution role ARN"
  value       = aws_iam_role.ecs_execution.arn
}

output "ecs_task_role_arn" {
  description = "ECS task role ARN"
  value       = aws_iam_role.ecs_task.arn
}

output "ssm_parameter_arn" {
  description = "SSM parameter ARN for the API token"
  value       = aws_ssm_parameter.api_token.arn
}

