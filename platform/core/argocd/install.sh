#!/bin/bash
set -euo pipefail

# Install ArgoCD as the central orchestration hub for multi-cluster management

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing ArgoCD in hub cluster..."

helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  -f "${SCRIPT_DIR}/values.yaml" \
  --version 7.7.5 \
  --wait \
  --timeout 10m

echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

echo "ArgoCD installed successfully!"
echo "Retrieve admin password with:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
