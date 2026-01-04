locals {
  base_name = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
  })
}

resource "aws_ssm_parameter" "api_token" {
  name  = "/${var.project_name}/${var.environment}/api_token"
  type  = "SecureString"
  value = var.api_token

  tags = merge(local.common_tags, {
    Name = "${local.base_name}-api-token"
  })
}

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "execution_policy" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/ecs/*"]
  }

  statement {
    actions   = ["ssm:GetParameters", "ssm:GetParameter"]
    resources = [aws_ssm_parameter.api_token.arn]
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "${local.base_name}-ecs-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
  tags               = merge(local.common_tags, { Name = "${local.base_name}-ecs-exec" })
}

resource "aws_iam_role_policy" "ecs_execution" {
  name   = "${local.base_name}-ecs-exec-policy"
  role   = aws_iam_role.ecs_execution.id
  policy = data.aws_iam_policy_document.execution_policy.json
}

data "aws_iam_policy_document" "task_policy" {
  statement {
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:SendMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ChangeMessageVisibility"
    ]
    resources = [var.sqs_queue_arn]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = ["${var.s3_bucket_arn}/*"]
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [var.s3_bucket_arn]
  }

  statement {
    actions   = ["ssm:GetParameters", "ssm:GetParameter"]
    resources = [aws_ssm_parameter.api_token.arn]
  }
}

resource "aws_iam_role" "ecs_task" {
  name               = "${local.base_name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
  tags               = merge(local.common_tags, { Name = "${local.base_name}-ecs-task" })
}

resource "aws_iam_role_policy" "ecs_task" {
  name   = "${local.base_name}-ecs-task-policy"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.task_policy.json
}

