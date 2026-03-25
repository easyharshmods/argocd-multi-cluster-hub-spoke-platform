#!/usr/bin/env bash
# Restart Dagster daemon to pick up configuration changes
set -euo pipefail

NAMESPACE="${NAMESPACE:-dagster}"

echo "Restarting Dagster daemon to pick up configuration changes..."
kubectl rollout restart deployment -n "${NAMESPACE}" -l "app.kubernetes.io/name=dagster,component=dagster-daemon"

echo "Waiting for daemon to be ready..."
kubectl rollout status deployment -n "${NAMESPACE}" -l "app.kubernetes.io/name=dagster,component=dagster-daemon" --timeout=120s

echo "✓ Daemon restarted. Check logs: kubectl logs -n ${NAMESPACE} -l component=dagster-daemon --tail=50"
