locals {
  service_base_name = var.name_suffix == "" ? "${var.project_name}-${var.environment}" : "${var.project_name}-${var.environment}-${var.name_suffix}"
  cluster_base_name = var.cluster_name_override != "" ? var.cluster_name_override : "${var.project_name}-${var.environment}"
  # base_name kept for backward references (logs, task family)
  base_name         = var.name_suffix == "" ? "${var.project_name}-${var.environment}" : "${var.project_name}-${var.environment}-${var.name_suffix}"
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
  })
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${local.base_name}/${var.container_name}"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${local.base_name}-logs"
  })
}

resource "aws_ecs_cluster" "this" {
  count = var.create_cluster ? 1 : 0

  name = "${local.cluster_base_name}-cluster"

  setting {
    name  = "containerInsights"
    value = var.container_insights_enabled ? "enabled" : "disabled"
  }

  tags = merge(local.common_tags, {
    Name = "${local.cluster_base_name}-cluster"
  })
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  count = var.create_cluster ? 1 : 0

  cluster_name = aws_ecs_cluster.this[0].name
  capacity_providers = [
    "FARGATE",
    "FARGATE_SPOT"
  ]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

locals {
  cluster_name = var.create_cluster ? aws_ecs_cluster.this[0].name : var.existing_cluster_name
  cluster_arn  = var.create_cluster ? aws_ecs_cluster.this[0].arn : var.existing_cluster_arn
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${local.base_name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.container_image
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      environment = [
        for k, v in var.environment_variables : {
          name  = k
          value = v
        }
      ]
      secrets = [
        for k, v in var.secrets : {
          name      = k
          valueFrom = v
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = var.container_name
        }
      }
    }
  ])

  tags = merge(local.common_tags, {
    Name = "${local.base_name}-taskdef"
  })
}

resource "aws_ecs_service" "this" {
  name            = "${local.service_base_name}-service"
  cluster         = local.cluster_arn != "" ? local.cluster_arn : local.cluster_name
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.security_group_id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = var.attach_to_alb ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.base_name}-service"
  })

  depends_on = [aws_ecs_cluster_capacity_providers.this]
}

resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${local.cluster_name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${local.base_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_target_value
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "memory" {
  name               = "${local.base_name}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.memory_target_value
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

