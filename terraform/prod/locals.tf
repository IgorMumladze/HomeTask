locals {
  base_name = "${var.project_name}-${var.environment}"

  merged_env_vars = merge(
    var.environment_variables,
    {
      ENVIRONMENT = var.environment
      QUEUE_URL   = module.queue.queue_url
      S3_BUCKET   = module.storage.bucket_name
    }
  )

  merged_secret_vars = merge(
    { API_TOKEN = module.security.ssm_parameter_arn },
    var.secrets
  )

  alb_forward_action = [{
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }]

  api_container_name    = "${var.project_name}-api"
  worker_container_name = "${var.project_name}-worker"

  api_repo_url    = module.ecr.repository_urls["api"]
  worker_repo_url = module.ecr.repository_urls["worker"]

  api_image_uri    = "${local.api_repo_url}:${var.api_image_tag}"
  worker_image_uri = "${local.worker_repo_url}:${var.worker_image_tag}"

  combined_env_vars = merge(
    local.merged_env_vars,
    {
      AWS_REGION    = var.aws_region
      USE_MOCK_SQS  = "false"
      SQS_QUEUE_URL = module.queue.queue_url
    }
  )
}

