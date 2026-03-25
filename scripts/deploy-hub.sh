#!/bin/bash
set -euo pipefail

# Deploy hub cluster with ArgoCD

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==================================================================="
echo "Deploying Hub Cluster"
echo "==================================================================="

# 1. Deploy hub infrastructure
echo ">>> Step 1: Deploying hub cluster infrastructure..."
cd "${PROJECT_ROOT}/infrastructure/hub"
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 2. Configure kubectl
echo ">>> Step 2: Configuring kubectl..."
HUB_CLUSTER_NAME=$(terraform output -raw cluster_name)
aws eks update-kubeconfig --name "${HUB_CLUSTER_NAME}" --region eu-central-1 --alias hub

# 3. Install ArgoCD
echo ">>> Step 3: Installing ArgoCD..."
cd "${PROJECT_ROOT}/platform/core/argocd"
./install.sh

# 4. Wait for ArgoCD to be ready
echo ">>> Step 4: Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

# 5. Get ArgoCD initial password
echo ">>> Step 5: Retrieving ArgoCD credentials..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo "==================================================================="
echo "Hub cluster deployed successfully!"
echo "==================================================================="
echo "ArgoCD URL: https://argocd.example.com"
echo "Username: admin"
echo "Password: ${ARGOCD_PASSWORD}"
echo "==================================================================="
echo ""
echo "Next steps:"
echo "1. Access ArgoCD UI and change the admin password"
echo "2. Deploy spoke clusters: ./scripts/deploy-spoke.sh dev"
echo "3. Configure GitHub webhook for ArgoCD"
echo "==================================================================="
