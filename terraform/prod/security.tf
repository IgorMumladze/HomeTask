module "security" {
  source         = "../modules/security"
  project_name   = var.project_name
  environment    = var.environment
  aws_region     = var.aws_region
  aws_account_id = data.aws_caller_identity.current.account_id
  sqs_queue_arn  = module.queue.queue_arn
  s3_bucket_arn  = module.storage.bucket_arn
  api_token      = var.api_token
  tags           = var.tags
}

