#!/bin/bash
set -e

# Generate a random suffix for uniqueness
SUFFIX=$RANDOM
BUCKET_NAME="terraform-state-backend-${SUFFIX}"
TABLE_NAME="terraform-locks-${SUFFIX}"
REGION="us-east-2"

echo "Creating S3 Bucket for Terraform State: $BUCKET_NAME"
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "Bucket already exists."
else
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"
    
    # Enable versioning
    aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled
    
    # Enable encryption
    aws s3api put-bucket-encryption --bucket "$BUCKET_NAME" --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
fi

echo "Creating DynamoDB Table for State Locking: $TABLE_NAME"
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "Table already exists."
else
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$REGION"
fi

echo "Backend Infrastructure Created."
echo "Bucket: $BUCKET_NAME"
echo "Table:  $TABLE_NAME"

# Update provider.tf with these values
# We need to use sed or just print instructions. 
# Since we are automating, we will write a temporary tf file or update the existing one using sed.

OS_TYPE=$(uname)
if [ "$OS_TYPE" = "Darwin" ]; then
    SED_CMD="sed -i ''"
else
    SED_CMD="sed -i"
fi

# We can't easily update terraform { backend "s3" {} } if it doesn't exist.
# Easier to overwrite the terraform {} block.

cat > terraform/backend.tf <<EOF
terraform {
  backend "s3" {
    bucket         = "${BUCKET_NAME}"
    key            = "global/s3/terraform.tfstate"
    region         = "${REGION}"
    dynamodb_table = "${TABLE_NAME}"
    encrypt        = true
  }
}
EOF

echo "Created terraform/backend.tf with backend configuration."
