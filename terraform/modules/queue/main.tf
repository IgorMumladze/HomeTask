locals {
  base_name = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
  })
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${local.base_name}-dlq"
  message_retention_seconds = max(var.message_retention_seconds, 60 * 60 * 24) # keep DLQ messages at least a day

  tags = merge(local.common_tags, {
    Name = "${local.base_name}-dlq"
  })
}

resource "aws_sqs_queue" "main" {
  name                       = "${local.base_name}-queue"
  delay_seconds              = var.delay_seconds
  message_retention_seconds  = var.message_retention_seconds
  visibility_timeout_seconds = var.visibility_timeout_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = merge(local.common_tags, {
    Name = "${local.base_name}-queue"
  })
}

