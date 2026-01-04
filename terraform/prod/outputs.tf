output "vpc_id" {
  value       = module.networking.vpc_id
  description = "VPC ID"
}

output "public_subnet_ids" {
  value       = module.networking.public_subnet_ids
  description = "Public subnet IDs"
}

output "private_subnet_ids" {
  value       = module.networking.private_subnet_ids
  description = "Private subnet IDs"
}

output "alb_dns_name" {
  value       = aws_lb.this.dns_name
  description = "ALB DNS name"
}

output "target_group_arn" {
  value       = aws_lb_target_group.this.arn
  description = "ALB target group ARN"
}

output "ecs_service_name" {
  value       = module.ecs_api.service_name
  description = "ECS service name (API)"
}

output "ecs_worker_service_name" {
  value       = module.ecs_worker.service_name
  description = "ECS service name (worker)"
}

output "api_image_uri" {
  value       = local.api_image_uri
  description = "Computed API image URI (ECR repo + tag)"
}

output "worker_image_uri" {
  value       = local.worker_image_uri
  description = "Computed worker image URI (ECR repo + tag)"
}

output "s3_bucket_name" {
  value       = module.storage.bucket_name
  description = "S3 bucket name"
}

output "sqs_queue_url" {
  value       = module.queue.queue_url
  description = "SQS queue URL"
}

output "ssm_parameter_arn" {
  value       = module.security.ssm_parameter_arn
  description = "SSM parameter ARN for API token"
}

output "ecr_repository_urls" {
  value       = module.ecr.repository_urls
  description = "Map of ECR repository URLs by suffix (e.g., api, worker)"
}

