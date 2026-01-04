module "queue" {
  source                     = "../modules/queue"
  project_name               = var.project_name
  environment                = var.environment
  delay_seconds              = var.queue_delay_seconds
  message_retention_seconds  = var.queue_message_retention_seconds
  visibility_timeout_seconds = var.queue_visibility_timeout_seconds
  max_receive_count          = var.queue_max_receive_count
  tags                       = var.tags
}

