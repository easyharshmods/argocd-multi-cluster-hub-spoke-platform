#!/bin/bash
set -euo pipefail

# Verify multi-cluster deployment health

echo "==================================================================="
echo "Verifying Multi-Cluster Deployment"
echo "==================================================================="

ERRORS=0

# 1. Check hub cluster health
echo ""
echo ">>> Checking hub cluster..."
if kubectl get nodes --context hub &>/dev/null; then
  echo "  Nodes: $(kubectl get nodes --context hub --no-headers | wc -l) nodes ready"
else
  echo "  WARNING: Hub cluster not configured"
  ERRORS=$((ERRORS + 1))
fi

if kubectl get pods -n argocd --context hub &>/dev/null; then
  ARGOCD_READY=$(kubectl get pods -n argocd --context hub --no-headers | grep -c "Running" || true)
  echo "  ArgoCD: ${ARGOCD_READY} pods running"
else
  echo "  WARNING: ArgoCD not installed"
  ERRORS=$((ERRORS + 1))
fi

if kubectl get applications -n argocd --context hub &>/dev/null; then
  APP_COUNT=$(kubectl get applications -n argocd --context hub --no-headers | wc -l)
  SYNCED=$(kubectl get applications -n argocd --context hub --no-headers | grep -c "Synced" || true)
  echo "  Applications: ${SYNCED}/${APP_COUNT} synced"
else
  echo "  WARNING: No applications found"
fi

# 2. Check spoke clusters
for env in dev staging prod; do
  echo ""
  echo ">>> Checking ${env} spoke..."
  if kubectl get nodes --context "${env}" &>/dev/null; then
    NODES=$(kubectl get nodes --context "${env}" --no-headers | wc -l)
    echo "  Nodes: ${NODES} nodes ready"
  else
    echo "  WARNING: ${env} cluster not configured"
    continue
  fi

  if kubectl get pods -n dagster --context "${env}" &>/dev/null; then
    DAGSTER_READY=$(kubectl get pods -n dagster --context "${env}" --no-headers | grep -c "Running" || true)
    DAGSTER_TOTAL=$(kubectl get pods -n dagster --context "${env}" --no-headers | wc -l)
    echo "  Dagster: ${DAGSTER_READY}/${DAGSTER_TOTAL} pods running"
  else
    echo "  WARNING: Dagster not deployed in ${env}"
  fi
done

# 3. Summary
echo ""
echo "==================================================================="
if [ ${ERRORS} -eq 0 ]; then
  echo "All checks passed!"
else
  echo "WARNING: ${ERRORS} issue(s) detected. Review output above."
fi
echo "==================================================================="
