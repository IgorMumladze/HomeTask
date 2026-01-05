locals {
  dashboard_name = "${local.base_name}-monitoring-dashboard"
  queue_name     = "${local.base_name}-queue"
  cicd_namespace = "HomeTask/CICD"
  cicd_build_workflow  = "build-and-push-ecr"
  cicd_deploy_workflow = "deploy-ecs"

  dashboard_body = jsonencode({
    widgets = [
      {
        type    = "metric"
        x       = 0
        y       = 0
        width   = 24
        height  = 6
        properties = {
          view       = "timeSeries"
          stacked    = false
          region     = var.aws_region
          title      = "ALB latency & 5xx errors"
          metrics    = [
            [
              "AWS/ApplicationELB",
              "TargetResponseTime",
              "LoadBalancer",
              aws_lb.this.name
            ],
            [
              "AWS/ApplicationELB",
              "HTTPCode_Target_5XX_Count",
              "LoadBalancer",
              aws_lb.this.name
            ]
          ]
          stat       = "Average"
          period     = 300
        }
      },
      {
        type    = "metric"
        x       = 0
        y       = 6
        width   = 12
        height  = 6
        properties = {
          view       = "timeSeries"
          stacked    = false
          region     = var.aws_region
          title      = "API CPU / Memory"
          metrics    = [
            [
              "AWS/ECS",
              "CPUUtilization",
              "ClusterName",
              module.ecs_api.cluster_name,
              "ServiceName",
              module.ecs_api.service_name
            ],
            [
              "AWS/ECS",
              "MemoryUtilization",
              "ClusterName",
              module.ecs_api.cluster_name,
              "ServiceName",
              module.ecs_api.service_name
            ]
          ]
          stat       = "Average"
          period     = 300
        }
      },
      {
        type    = "metric"
        x       = 12
        y       = 6
        width   = 12
        height  = 6
        properties = {
          view       = "timeSeries"
          stacked    = false
          region     = var.aws_region
          title      = "Worker CPU / Memory"
          metrics    = [
            [
              "AWS/ECS",
              "CPUUtilization",
              "ClusterName",
              module.ecs_worker.cluster_name,
              "ServiceName",
              module.ecs_worker.service_name
            ],
            [
              "AWS/ECS",
              "MemoryUtilization",
              "ClusterName",
              module.ecs_worker.cluster_name,
              "ServiceName",
              module.ecs_worker.service_name
            ]
          ]
          stat       = "Average"
          period     = 300
        }
      },
      {
        type    = "metric"
        x       = 0
        y       = 12
        width   = 12
        height  = 6
        properties = {
          view       = "timeSeries"
          stacked    = false
          region     = var.aws_region
          title      = "Running task counts"
          metrics    = [
            [
              "AWS/ECS",
              "RunningTaskCount",
              "ClusterName",
              module.ecs_api.cluster_name,
              "ServiceName",
              module.ecs_api.service_name
            ],
            [
              "AWS/ECS",
              "RunningTaskCount",
              "ClusterName",
              module.ecs_worker.cluster_name,
              "ServiceName",
              module.ecs_worker.service_name
            ]
          ]
          stat       = "Average"
          period     = 300
        }
      },
      {
        type    = "metric"
        x       = 12
        y       = 12
        width   = 12
        height  = 6
        properties = {
          view       = "timeSeries"
          stacked    = false
          region     = var.aws_region
          title      = "SQS depth + oldest message"
          metrics    = [
            [
              "AWS/SQS",
              "ApproximateNumberOfMessagesVisible",
              "QueueName",
              local.queue_name
            ],
            [
              "AWS/SQS",
              "ApproximateAgeOfOldestMessage",
              "QueueName",
              local.queue_name
            ]
          ]
          stat       = "Average"
          period     = 300
        }
      },
      {
        type    = "metric"
        x       = 0
        y       = 18
        width   = 24
        height  = 6
        properties = {
          view       = "timeSeries"
          stacked    = false
          region     = var.aws_region
          title      = "CI/CD success vs failure"
          metrics    = [
            [
              local.cicd_namespace,
              "BuildSuccess",
              "Workflow",
              local.cicd_build_workflow
            ],
            [
              local.cicd_namespace,
              "BuildFailure",
              "Workflow",
              local.cicd_build_workflow
            ],
            [
              local.cicd_namespace,
              "DeploySuccess",
              "Workflow",
              local.cicd_deploy_workflow
            ],
            [
              local.cicd_namespace,
              "DeployFailure",
              "Workflow",
              local.cicd_deploy_workflow
            ]
          ]
          stat       = "Sum"
          period     = 300
        }
      }
    ]
  })
}

resource "aws_cloudwatch_dashboard" "monitoring" {
  dashboard_name = local.dashboard_name
  dashboard_body = local.dashboard_body
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name                = "${local.base_name}-alb-5xx"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = "HTTPCode_Target_5XX_Count"
  namespace                 = "AWS/ApplicationELB"
  period                    = 300
  statistic                 = "Sum"
  threshold                 = 5
  alarm_description         = "ALB 5xx errors indicate backend failures."
  dimensions = {
    LoadBalancer = aws_lb.this.name
  }
  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "ecs_api_cpu" {
  alarm_name          = "${local.base_name}-api-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  dimensions = {
    ClusterName = module.ecs_api.cluster_name
    ServiceName = module.ecs_api.service_name
  }
  alarm_description  = "API service CPU is saturated."
  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "ecs_worker_cpu" {
  alarm_name          = "${local.base_name}-worker-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  dimensions = {
    ClusterName = module.ecs_worker.cluster_name
    ServiceName = module.ecs_worker.service_name
  }
  alarm_description  = "Worker service CPU is saturated."
  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "ecs_api_running" {
  alarm_name                = "${local.base_name}-api-running"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = 1
  metric_name               = "RunningTaskCount"
  namespace                 = "AWS/ECS"
  period                    = 60
  statistic                 = "Minimum"
  threshold                 = var.api_ecs_desired_count
  dimensions = {
    ClusterName = module.ecs_api.cluster_name
    ServiceName = module.ecs_api.service_name
  }
  alarm_description  = "API service is not maintaining the desired task count."
  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "ecs_worker_running" {
  alarm_name                = "${local.base_name}-worker-running"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = 1
  metric_name               = "RunningTaskCount"
  namespace                 = "AWS/ECS"
  period                    = 60
  statistic                 = "Minimum"
  threshold                 = var.worker_ecs_desired_count
  dimensions = {
    ClusterName = module.ecs_worker.cluster_name
    ServiceName = module.ecs_worker.service_name
  }
  alarm_description  = "Worker service is not maintaining the desired task count."
  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "sqs_depth" {
  alarm_name          = "${local.base_name}-queue-depth"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 30
  dimensions = {
    QueueName = local.queue_name
  }
  alarm_description  = "SQS queue is accumulating messages, worker may be lagging."
  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "sqs_age" {
  alarm_name          = "${local.base_name}-queue-oldest"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 600
  dimensions = {
    QueueName = local.queue_name
  }
  alarm_description  = "Messages are waiting in the queue for more than 10 minutes."
  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "ci_build_failure" {
  alarm_name          = "${local.base_name}-ci-build-failure"
  alarm_description   = "Build workflow failed"
  metric_name         = "BuildFailure"
  namespace           = local.cicd_namespace
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  dimensions = {
    Workflow = local.cicd_build_workflow
  }
  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "ci_deploy_failure" {
  alarm_name          = "${local.base_name}-ci-deploy-failure"
  alarm_description   = "Deploy workflow failed"
  metric_name         = "DeployFailure"
  namespace           = local.cicd_namespace
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  dimensions = {
    Workflow = local.cicd_deploy_workflow
  }
  treat_missing_data = "notBreaching"
}

