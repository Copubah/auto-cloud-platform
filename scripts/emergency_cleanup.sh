#!/bin/bash
set -e

REGION="us-east-2"
PROJECT_TAG="auto-cloud-platform"

echo "WARNING: This script will delete ALL resources with tag Project=${PROJECT_TAG} in ${REGION}."
echo "This is an emergency cleanup script for orphaned resources."
echo "Press Ctrl+C to cancel, or wait 5 seconds..."
sleep 5

echo "Finding and Deleting Resources..."

# 1. Delete ECS Service and Cluster
CLUSTERS=$(aws ecs list-clusters --region $REGION --query "clusterArns[]" --output text)
for cluster in $CLUSTERS; do
    if [[ $cluster == *"${PROJECT_TAG}"* ]]; then
        echo "Deleting Cluster: $cluster"
        SERVICES=$(aws ecs list-services --cluster $cluster --region $REGION --query "serviceArns[]" --output text)
        for service in $SERVICES; do
            echo "  Deleting Service: $service"
            aws ecs update-service --cluster $cluster --service $service --desired-count 0 --region $REGION >/dev/null
            aws ecs delete-service --cluster $cluster --service $service --force --region $REGION >/dev/null
        done
        # Wait for services to drain? No, just force delete cluster if possible or wait
        sleep 5
        aws ecs delete-cluster --cluster $cluster --region $REGION || echo "  Failed to delete cluster (might still have tasks)"
    fi
done

# 2. Delete Load Balancers
LBS=$(aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[?contains(LoadBalancerName, '${PROJECT_TAG}')].LoadBalancerArn" --output text)
for lb in $LBS; do
    echo "Deleting ALB: $lb"
    aws elbv2 delete-load-balancer --load-balancer-arn $lb --region $REGION
    sleep 5 # Wait for deletion
done

# 3. Delete Target Groups
TGS=$(aws elbv2 describe-target-groups --region $REGION --query "TargetGroups[?contains(TargetGroupName, '${PROJECT_TAG}')].TargetGroupArn" --output text)
for tg in $TGS; do
  echo "Deleting Target Group: $tg"
  aws elbv2 delete-target-group --target-group-arn $tg --region $REGION
done

# 4. Delete RDS
DBS=$(aws rds describe-db-instances --region $REGION --query "DBInstances[?contains(DBInstanceIdentifier, '${PROJECT_TAG}')].DBInstanceIdentifier" --output text)
for db in $DBS; do
    echo "Deleting RDS: $db"
    aws rds delete-db-instance --db-instance-identifier $db --skip-final-snapshot --delete-automated-backups --region $REGION || echo "  Already deleting?"
    echo "  Waiting for RDS deletion (this takes time, continuing async...)"
done

# 5. Delete Security Groups (Need to clear dependencies first, doing VPC last usually works)
# We will rely on VPC deletion for SGs if they are attached to VPC
# But we need to delete them explicitly if we want to be clean.
# Skipping for now, VPC deletion usually fails if SGs have dependencies.

# 6. Delete NAT Gateways
NAT_GWS=$(aws ec2 describe-nat-gateways --region $REGION --filter "Name=tag:Project,Values=${PROJECT_TAG}" --query "NatGateways[].NatGatewayId" --output text)
for nat in $NAT_GWS; do
    echo "Deleting NAT GW: $nat"
    aws ec2 delete-nat-gateway --nat-gateway-id $nat --region $REGION
    echo "  Waiting for NAT GW to delete..."
    aws ec2 wait nat-gateway-deleted --nat-gateway-ids $nat --region $REGION
done

# 7. Release EIPs
EIPS=$(aws ec2 describe-addresses --region $REGION --filter "Name=tag:Project,Values=${PROJECT_TAG}" --query "Addresses[].AllocationId" --output text)
for eip in $EIPS; do
    echo "Releasing EIP: $eip"
    aws ec2 release-address --allocation-id $eip --region $REGION
done

# 8. Delete Internet Gateway
# We need to detach first.
VPS_IDS=$(aws ec2 describe-vpcs --region $REGION --filter "Name=tag:Project,Values=${PROJECT_TAG}" --query "Vpcs[].VpcId" --output text)
for vpc in $VPS_IDS; do
    IGW=$(aws ec2 describe-internet-gateways --region $REGION --filter "Name=attachment.vpc-id,Values=${vpc}" --query "InternetGateways[].InternetGatewayId" --output text)
    if [ ! -z "$IGW" ] && [ "$IGW" != "None" ]; then
        echo "Detaching and Deleting IGW: $IGW"
        aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $vpc --region $REGION
        aws ec2 delete-internet-gateway --internet-gateway-id $IGW --region $REGION
    fi
     
    # Delete Subnets
    SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${vpc}" --region $REGION --query "Subnets[].SubnetId" --output text)
    for sub in $SUBNETS; do
        echo "Deleting Subnet: $sub"
        aws ec2 delete-subnet --subnet-id $sub --region $REGION
    done

    # Delete Route Tables (Non-main)
    RTS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${vpc}" --region $REGION --query "RouteTables[?Associations==[] && RouteTableId!='rtb-main'].RouteTableId" --output text)
    # The filter above is tricky, deleting all non-main RTs
    ALL_RTS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${vpc}" --region $REGION --query "RouteTables[].RouteTableId" --output text)
    for rt in $ALL_RTS; do
         # Try to delete, ignore if main
         aws ec2 delete-route-table --route-table-id $rt --region $REGION 2>/dev/null || true
    done

    # Delete Security Groups
    SGS=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=${vpc}" --region $REGION --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)
    for sg in $SGS; do
        echo "Deleting SG: $sg"
        aws ec2 delete-security-group --group-id $sg --region $REGION 2>/dev/null || echo "  SG $sg in use, retrying later"
    done

    echo "Deleting VPC: $vpc"
    aws ec2 delete-vpc --vpc-id $vpc --region $REGION
done

# 9. Delete ECR Repo
REPOS=$(aws ecr describe-repositories --region $REGION --query "repositories[?contains(repositoryName, '${PROJECT_TAG}')].repositoryName" --output text)
for repo in $REPOS; do
    echo "Deleting ECR Repo: $repo"
    aws ecr delete-repository --repository-name $repo --force --region $REGION
done

# 10. Delete Log Groups
LOGS=$(aws logs describe-log-groups --region $REGION --log-group-name-prefix "/ecs/${PROJECT_TAG}" --query "logGroups[].logGroupName" --output text)
for log in $LOGS; do
    echo "Deleting Log Group: $log"
    aws logs delete-log-group --log-group-name $log --region $REGION
done

# 11. Delete GuardDuty Detector? (Hard to identify by tag usually, skipping for now)

echo "Cleanup attempt complete. Some resources (like RDS) take time to delete."
