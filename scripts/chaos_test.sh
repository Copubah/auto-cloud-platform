#!/bin/bash
set -e

echo "Simulating Failure (Chaos Test)..."

REGION=$(cd terraform && terraform output -raw region 2>/dev/null || echo "us-east-1")
CLUSTER=$(cd terraform && terraform output -raw ecs_cluster_name)
SERVICE=$(cd terraform && terraform output -raw ecs_service_name)
URL="http://$(cd terraform && terraform output -raw alb_dns_name)"

echo "Targeting Cluster: $CLUSTER, Service: $SERVICE"

# Get a running task
TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER --service-name $SERVICE --region $REGION --query "taskArns[0]" --output text)

if [ "$TASK_ARN" == "None" ]; then
    echo "No tasks running!"
    exit 1
fi

echo "Killing Task: $TASK_ARN"
aws ecs stop-task --cluster $CLUSTER --task $TASK_ARN --region $REGION > /dev/null

echo "Task killed. Monitoring uptime at $URL..."

START_TIME=$(date +%s)
downtime=0

for i in {1..30}; do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" $URL || echo "000")
    if [ "$CODE" == "200" ]; then
        echo "[$i] Status: 200 OK (Recovered/Healthy)"
    else
        echo "[$i] Status: $CODE (Impact Detected)"
        downtime=$((downtime+1))
    fi
    sleep 2
done

echo "Test Complete."
if [ $downtime -eq 0 ]; then
    echo "Result: ZERO Downtime achieved (or instant recovery)!"
else
    echo "Result: $downtime failed checks observed."
fi
