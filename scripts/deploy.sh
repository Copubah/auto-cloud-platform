#!/bin/bash
set -e

# Checks
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "Error: AWS credentials not set in environment."
    exit 1
fi

echo "Initializing Terraform..."
cd terraform
terraform init

echo "Applying Infrastructure..."
terraform apply -auto-approve

echo "Gathering Outputs..."
REPO_URL=$(terraform output -raw ecr_repository_url)
REPO_NAME=$(echo $REPO_URL | cut -d'/' -f2)
REGION=$(terraform output -raw region 2>/dev/null || echo "us-east-1") # defaulting if output missing

echo "Building and Pushing Docker Image..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REPO_URL
cd ../app
docker build -t $REPO_URL:latest .
docker push $REPO_URL:latest

echo "Updating ECS Service..."
cd ../terraform
terraform apply -auto-approve -var="app_image=$REPO_URL:latest"

echo "Deployment Complete!"
echo "URL: http://$(terraform output -raw alb_dns_name)"
