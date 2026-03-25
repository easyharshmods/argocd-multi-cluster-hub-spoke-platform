#!/usr/bin/env bash
# Print pod describe and logs for the Dagster user-code deployment.
# Use when the user-code pod is in CrashLoopBackOff and kubectl logs are empty.
set -euo pipefail

echo "=== User-code pods ==="
kubectl get pods -n dagster -l 'app.kubernetes.io/name=dagster,component=user-deployments' -o wide 2>/dev/null || \
  kubectl get pods -n dagster | grep -E 'user-code|user-deployments' || true

POD="$(kubectl get pods -n dagster -l 'app.kubernetes.io/name=dagster,component=user-deployments' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)" || true
if [[ -z "${POD}" ]]; then
  POD="$(kubectl get pods -n dagster --no-headers 2>/dev/null | awk '/user-code|user-deployments/{print $1; exit}')"
fi

if [[ -z "${POD}" ]]; then
  echo "No user-code pod found in namespace dagster."
  exit 1
fi

echo ""
echo "=== Describe pod (exit code, reason, events) ==="
kubectl describe pod -n dagster "${POD}"

echo ""
echo "=== Logs (current) ==="
kubectl logs -n dagster "${POD}" --tail=200 2>/dev/null || echo "(no logs)"

echo ""
echo "=== Logs (previous instance) ==="
kubectl logs -n dagster "${POD}" --previous --tail=200 2>/dev/null || echo "(no previous logs)"
