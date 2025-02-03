#!/bin/bash
set -e

# Configuration
region="us-east-2"
account_id="093487613626"
ecr_repo_name="gen_presigned_url"
docker_image="gen_presigned_url"
aws_profile="pdfreader"

# ECR repository URI
ecr_repo_uri="${account_id}.dkr.ecr.${region}.amazonaws.com/${ecr_repo_name}"

# Login to ECR
echo "Authenticating Docker with ECR..."
aws ecr get-login-password --region $region --profile $aws_profile | \
  docker login --username AWS --password-stdin $ecr_repo_uri

# Build Docker image
echo "Building Docker image..."
docker build -t $docker_image .

# Tag the image
echo "Tagging image..."
docker tag $docker_image:latest $ecr_repo_uri:latest

# Push the image
echo "Pushing image to ECR..."
docker push $ecr_repo_uri:latest

echo "Image pushed successfully to: $ecr_repo_uri:latest"
