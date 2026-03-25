#!/bin/bash
set -euo pipefail

# Build and push Dagster Docker image to ECR

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Building Dagster Docker Image${NC}"
echo -e "${BLUE}=========================================${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source environment variables from foundation env (if not already set)
if [ -n "${ECR_REPOSITORY_URL:-}" ] && [ -n "${AWS_REGION:-}" ]; then
  echo -e "${GREEN}Using pre-set environment variables${NC}"
elif [ -f "${REPO_ROOT}/platform/dagster/foundation.env" ]; then
  source "${REPO_ROOT}/platform/dagster/foundation.env"
  echo -e "${GREEN}Loaded environment from platform/dagster/foundation.env${NC}"
elif [ -f "${REPO_ROOT}/infrastructure/outputs/foundation.env" ]; then
  source "${REPO_ROOT}/infrastructure/outputs/foundation.env"
  echo -e "${GREEN}Loaded environment from infrastructure/outputs/foundation.env${NC}"
else
  echo "ERROR: foundation.env not found. Either:"
  echo "  - Set ECR_REPOSITORY_URL and AWS_REGION as environment variables"
  echo "  - Place foundation.env in platform/dagster/ or infrastructure/outputs/"
  exit 1
fi

# Verify required variables
if [ -z "${ECR_REPOSITORY_URL:-}" ]; then
  echo "ERROR: ECR_REPOSITORY_URL not set"
  exit 1
fi

# Login to ECR
echo -e "${BLUE}Logging into ECR...${NC}"
ECR_REGISTRY="${ECR_REPOSITORY_URL%/*}"
aws ecr get-login-password --region "${AWS_REGION}" | \
  docker login --username AWS --password-stdin "${ECR_REGISTRY}"

# Generate image tag
IMAGE_TAG="v$(date +%Y%m%d-%H%M%S)"
GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "nogit")

echo -e "${BLUE}Building image...${NC}"
echo "Repository: ${ECR_REPOSITORY_URL}"
echo "Tag: ${IMAGE_TAG}"
echo "Git SHA: ${GIT_SHA}"

# Build image
docker build \
  --platform linux/amd64 \
  --build-arg GIT_SHA="${GIT_SHA}" \
  -t dagster-user-code:latest \
  -t "dagster-user-code:${IMAGE_TAG}" \
  "${SCRIPT_DIR}"

# Tag for ECR
docker tag dagster-user-code:latest "${ECR_REPOSITORY_URL}:latest"
docker tag "dagster-user-code:${IMAGE_TAG}" "${ECR_REPOSITORY_URL}:${IMAGE_TAG}"

# Push to ECR
echo -e "${BLUE}Pushing to ECR...${NC}"
docker push "${ECR_REPOSITORY_URL}:latest"
docker push "${ECR_REPOSITORY_URL}:${IMAGE_TAG}"

# Write outputs for platform/dagster
echo -e "${BLUE}Writing outputs...${NC}"
mkdir -p "${REPO_ROOT}/platform/dagster"
cat > "${REPO_ROOT}/platform/dagster/application.env" <<EOT
# Auto-generated from applications/dagster-project
# DO NOT EDIT MANUALLY

export IMAGE_TAG="${IMAGE_TAG}"
export IMAGE_URI="${ECR_REPOSITORY_URL}:${IMAGE_TAG}"
export IMAGE_LATEST="${ECR_REPOSITORY_URL}:latest"
export BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
export GIT_SHA="${GIT_SHA}"
EOT

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo "Image: ${ECR_REPOSITORY_URL}:${IMAGE_TAG}"
echo "Outputs written to: ${REPO_ROOT}/platform/dagster/application.env"
