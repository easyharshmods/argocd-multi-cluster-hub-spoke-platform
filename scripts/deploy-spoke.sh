#!/bin/bash
set -euo pipefail

# Deploy spoke cluster and auto-register to hub

ENVIRONMENT="${1:-}"

if [ -z "${ENVIRONMENT}" ]; then
  echo "Usage: $0 <environment>"
  echo "Example: $0 dev"
  exit 1
fi

if [[ ! "${ENVIRONMENT}" =~ ^(dev|staging|prod)$ ]]; then
  echo "Error: Environment must be dev, staging, or prod"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==================================================================="
echo "Deploying ${ENVIRONMENT} Spoke Cluster"
echo "==================================================================="

# 1. Deploy spoke infrastructure
echo ">>> Step 1: Deploying spoke cluster infrastructure..."
cd "${PROJECT_ROOT}/infrastructure/spokes/${ENVIRONMENT}"
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 2. Configure kubectl for spoke
echo ">>> Step 2: Configuring kubectl for spoke..."
SPOKE_CLUSTER_NAME=$(terraform output -raw cluster_name)
aws eks update-kubeconfig --name "${SPOKE_CLUSTER_NAME}" \
  --region eu-central-1 --alias "${ENVIRONMENT}"

# 3. Wait for cluster to be ready
echo ">>> Step 3: Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s \
  --context "${ENVIRONMENT}"

# 4. Run auto-registration
echo ">>> Step 4: Registering spoke to hub ArgoCD..."
cd "${PROJECT_ROOT}/infrastructure/spokes/${ENVIRONMENT}/registration"

export ENVIRONMENT="${ENVIRONMENT}"
export SPOKE_CLUSTER_NAME="${SPOKE_CLUSTER_NAME}"
./register.sh

echo "==================================================================="
echo "${ENVIRONMENT} spoke cluster deployed and registered!"
echo "==================================================================="
echo ""
echo "Cluster: ${SPOKE_CLUSTER_NAME}"
echo "Environment: ${ENVIRONMENT}"
echo ""
echo "Next steps:"
echo "1. Check ArgoCD UI to see the registered cluster"
echo "2. Deploy applications: kubectl apply -f gitops/applications/${ENVIRONMENT}/"
echo "==================================================================="
