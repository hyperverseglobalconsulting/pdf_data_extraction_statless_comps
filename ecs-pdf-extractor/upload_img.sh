#!/bin/bash

# Variables
REPOSITORY_NAME="pdf-extractor" # Use the ECR repository name "pdf-extractor"
IMAGE_TAG="latest"
AWS_PROFILE="pdfreader" # Use the AWS profile named "pdfreader"

# Step 1: Build the Docker image
echo "Building Docker image..."
docker build -t ${REPOSITORY_NAME} .

# Step 2: Authenticate Docker to your ECR registry
echo "Authenticating Docker to ECR..."
aws ecr get-login-password --region ${AWS_REGION} --profile ${AWS_PROFILE} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Step 3: Tag the Docker image
echo "Tagging Docker image..."
docker tag ${REPOSITORY_NAME}:${IMAGE_TAG} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY_NAME}:${IMAGE_TAG}

# Step 4: Push the Docker image to ECR
echo "Pushing Docker image to ECR..."
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY_NAME}:${IMAGE_TAG}

echo "Docker image uploaded to ECR successfully!"
