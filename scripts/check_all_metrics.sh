#!/usr/bin/env bash
set -euo pipefail

AWS_PAGER="${AWS_PAGER:-}"
export AWS_PAGER=""

OUTPUT_FILE="${1:-}"
if [[ -n "$OUTPUT_FILE" ]]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  exec > >(tee -a "$OUTPUT_FILE")
  exec 2>&1
fi

NAMESPACE_CLOUDWATCH="aws"
END=$(python3 - <<'PY'
from datetime import datetime, timezone
print(datetime.now(timezone.utc).isoformat())
PY
)
START=$(python3 - <<'PY'
from datetime import datetime, timezone, timedelta
print((datetime.now(timezone.utc) - timedelta(minutes=30)).isoformat())
PY
)

metric_query() {
  local namespace=$1
  local metric_name=$2
  local dimensions=$3
  local stat=${4:-Average}
  local period=${5:-300}

  echo "=> $namespace::$metric_name [$dimensions]"
  aws cloudwatch get-metric-statistics \
    --namespace "$namespace" \
    --metric-name "$metric_name" \
    --dimensions $dimensions \
    --statistics "$stat" \
    --start-time "$START" \
    --end-time "$END" \
    --period "$period" \
    --output json
}

info() {
  echo
  echo "==> $*"
}

info "Using window $START → $END"

# ALB metrics
metric_query "AWS/ApplicationELB" "TargetResponseTime" "Name=LoadBalancer,Value=igor-home-task-prod-alb"
metric_query "AWS/ApplicationELB" "HTTPCode_Target_5XX_Count" "Name=LoadBalancer,Value=igor-home-task-prod-alb"

# ECS API metrics
metric_query "AWS/ECS" "CPUUtilization" "Name=ClusterName,Value=igor-home-task-prod-cluster Name=ServiceName,Value=igor-home-task-prod-api-service"
metric_query "AWS/ECS" "MemoryUtilization" "Name=ClusterName,Value=igor-home-task-prod-cluster Name=ServiceName,Value=igor-home-task-prod-api-service"
metric_query "AWS/ECS" "RunningTaskCount" "Name=ClusterName,Value=igor-home-task-prod-cluster Name=ServiceName,Value=igor-home-task-prod-api-service" "Average" 60

# ECS Worker metrics
metric_query "AWS/ECS" "CPUUtilization" "Name=ClusterName,Value=igor-home-task-prod-cluster Name=ServiceName,Value=igor-home-task-prod-worker-service"
metric_query "AWS/ECS" "MemoryUtilization" "Name=ClusterName,Value=igor-home-task-prod-cluster Name=ServiceName,Value=igor-home-task-prod-worker-service"
metric_query "AWS/ECS" "RunningTaskCount" "Name=ClusterName,Value=igor-home-task-prod-cluster Name=ServiceName,Value=igor-home-task-prod-worker-service" "Average" 60

# SQS metrics
metric_query "AWS/SQS" "ApproximateNumberOfMessagesVisible" "Name=QueueName,Value=igor-home-task-prod-queue"
metric_query "AWS/SQS" "ApproximateAgeOfOldestMessage" "Name=QueueName,Value=igor-home-task-prod-queue"

# Additional SQS flow metrics
metric_query "AWS/SQS" "NumberOfMessagesReceived" "Name=QueueName,Value=igor-home-task-prod-queue" "Sum" 300
metric_query "AWS/SQS" "NumberOfMessagesSent" "Name=QueueName,Value=igor-home-task-prod-queue" "Sum" 300
metric_query "AWS/SQS" "ApproximateNumberOfMessagesDelayed" "Name=QueueName,Value=igor-home-task-prod-queue"

# CI/CD metrics
metric_query "HomeTask/CICD" "BuildSuccess" "Name=Workflow,Value=build-and-push-ecr" "Sum" 60
metric_query "HomeTask/CICD" "BuildFailure" "Name=Workflow,Value=build-and-push-ecr" "Sum" 60
metric_query "HomeTask/CICD" "DeploySuccess" "Name=Workflow,Value=deploy-ecs" "Sum" 60
metric_query "HomeTask/CICD" "DeployFailure" "Name=Workflow,Value=deploy-ecs" "Sum" 60

