#!/bin/bash
set -e

# Checks
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "Error: AWS credentials not set in environment."
    exit 1
fi

echo "Destroying Infrastructure..."
cd terraform
terraform init
terraform destroy -auto-approve

echo "Destruction Complete."
