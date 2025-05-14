#!/bin/bash

# Fail on any error
set -e

# Constants
REPO_NAME="cloudbox-app"
REGION="us-east-2"
IMAGE_TAG="latest"
TARGET_HOST="172.31.7.108" #private ip
REMOTE_PROJECT_DIR="/home/ec2-user/cloudbox-deploy"

# Get AWS Account ID from STS
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Full ECR Image URI
ECR_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${IMAGE_TAG}"

echo "\u2714 AWS Account ID: $ACCOUNT_ID"
echo "\u2714 Target ECR URI: $ECR_URI"

# Authenticate Docker to ECR
echo "\ud83d\udd10 Logging in to ECR..."
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Build Docker image
echo "\ud83d\udc33 Building Docker image..."
docker build -t ${REPO_NAME} .

# Tag the image
echo "\ud83c\udff7\ufe0f Tagging image..."
docker tag ${REPO_NAME}:latest ${ECR_URI}

# Create repository if it doesn’t exist (optional safety)
echo "\ud83d\udce6 Creating ECR repo if not exists..."
aws ecr describe-repositories --repository-names "${REPO_NAME}" --region ${REGION} >/dev/null 2>&1 || \
aws ecr create-repository --repository-name "${REPO_NAME}" --region ${REGION}

# Push the image
echo "\ud83d\udce4 Pushing image to ECR..."
docker push ${ECR_URI}

echo "\u2705 Docker image successfully pushed to ECR!"

# SSH and redeploy on remote EC2
echo "\ud83d\ude80 Deploying to ${TARGET_HOST}..."
ssh ubuntu@${TARGET_HOST} << EOF
  set -e
  echo "\u274c Stopping existing containers..."
  cd ${REMOTE_PROJECT_DIR}
  docker compose down || true
  echo "\ud83d\udd04 Pulling latest image..."
  docker pull ${ECR_URI}
  echo "\u2705 Starting new containers..."
  docker compose up -d
EOF

echo "\ud83c\udf89 Deployment complete on ${TARGET_HOST}!"
