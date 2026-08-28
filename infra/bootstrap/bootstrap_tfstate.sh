#!/usr/bin/env bash
# Bootstrap the Terraform S3 backend state bucket and DynamoDB lock table.
set -euo pipefail

BUCKET="${1:-cloudzone-tfstate-952868634839}"
REGION="${2:-ap-south-1}"

echo "Creating S3 state bucket: $BUCKET in $REGION"
aws s3api create-bucket \
  --bucket "$BUCKET" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION" 2>/dev/null || echo "Bucket already exists (or name taken)."

aws s3api put-bucket-versioning \
  --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "$BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration '{"BlockPublicAcls":true,"IgnorePublicAcls":true,"BlockPublicPolicy":true,"RestrictPublicBuckets":true}'

echo "Creating DynamoDB lock table: terraform-locks"
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST 2>/dev/null || echo "Lock table already exists."

echo ""
echo "State bucket and lock table ready."
echo "Update infra/environments/<env>/backend.tf with bucket name: $BUCKET"
echo "Then run: terraform init -backend-config=bucket=$BUCKET"
