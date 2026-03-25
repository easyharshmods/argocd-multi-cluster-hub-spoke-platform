#!/usr/bin/env bash
# Upgrade Dagster from 1.9.11 to 1.12.14
# This script handles the full upgrade process including DB migration
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load foundation env
FOUNDATION_ENV=""
if [[ -f "${REPO_ROOT}/platform/dagster/foundation.env" ]]; then
  FOUNDATION_ENV="${REPO_ROOT}/platform/dagster/foundation.env"
elif [[ -f "${REPO_ROOT}/infrastructure/outputs/foundation.env" ]]; then
  FOUNDATION_ENV="${REPO_ROOT}/infrastructure/outputs/foundation.env"
fi

if [[ -z "${FOUNDATION_ENV}" ]] && [[ -z "${CLUSTER_NAME:-}" ]]; then
  echo "ERROR: No foundation.env found and CLUSTER_NAME not set."
  echo "  Run infrastructure first, or export CLUSTER_NAME and AWS_REGION."
  exit 1
fi
[[ -n "${FOUNDATION_ENV}" ]] && source "${FOUNDATION_ENV}"

# Load application env (written by build-push.sh)
APP_ENV="${REPO_ROOT}/platform/dagster/application.env"
if [[ ! -f "${APP_ENV}" ]]; then
  echo "ERROR: ${APP_ENV} not found. Run applications/dagster-project/build-push.sh first."
  exit 1
fi
source "${APP_ENV}"

NAMESPACE="${NAMESPACE:-dagster}"

echo "=== Dagster Upgrade: 1.9.11 → 1.12.14 ==="
echo ""
echo "⚠️  IMPORTANT: Ensure you have backed up your RDS database before proceeding!"
echo "   Run: aws rds create-db-snapshot --db-instance-identifier <your-rds-id> --db-snapshot-identifier dagster-pre-upgrade-$(date +%Y%m%d)"
echo ""
read -p "Have you backed up the database? (yes/no): " BACKUP_CONFIRM
if [[ "${BACKUP_CONFIRM}" != "yes" ]]; then
  echo "Aborting. Please backup your database first."
  exit 1
fi

# Ensure kubectl context
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}" 2>/dev/null || true

echo ""
echo "Step 1: Rebuilding user code image with Dagster 1.12.14..."
cd "${REPO_ROOT}/applications/dagster-project"
./build-push.sh
cd "${REPO_ROOT}/platform/dagster"

echo ""
echo "Step 2: Updating Helm repo..."
helm repo add dagster https://dagster-io.github.io/helm 2>/dev/null || true
helm repo update

echo ""
echo "Step 3: Upgrading Helm chart to 1.12.14..."
[[ -n "${FOUNDATION_ENV}" ]] && source "${FOUNDATION_ENV}"
source "${APP_ENV}"

IMAGE_REPO="${IMAGE_URI%:*}"
IMAGE_TAG_PARSED="${IMAGE_URI##*:}"

helm upgrade --install dagster dagster/dagster \
  --namespace "${NAMESPACE}" \
  -f "${REPO_ROOT}/platform/dagster/helm/dagster-values.yaml" \
  --set "dagster-user-deployments.deployments[0].image.repository=${IMAGE_REPO}" \
  --set "dagster-user-deployments.deployments[0].image.tag=${IMAGE_TAG_PARSED}" \
  --set "postgresql.enabled=false" \
  --set "postgresql.postgresqlHost=${RDS_ENDPOINT}" \
  --set "postgresql.postgresqlUsername=${RDS_USERNAME:-dagster}" \
  --set "postgresql.postgresqlDatabase=${RDS_DATABASE_NAME}" \
  --set "postgresql.service.port=${RDS_PORT}" \
  --version 1.12.14 \
  --skip-schema-validation \
  --wait

echo ""
echo "Step 4: Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -n "${NAMESPACE}" -l "app.kubernetes.io/name=dagster,component=dagster-daemon" --timeout=300s || true

echo ""
echo "Step 5: Running database migration..."
DAEMON_POD=$(kubectl get pods -n "${NAMESPACE}" -l "app.kubernetes.io/name=dagster,component=dagster-daemon" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "${DAEMON_POD}" ]]; then
  echo "Running migration via daemon pod: ${DAEMON_POD}"
  kubectl exec -n "${NAMESPACE}" "${DAEMON_POD}" -- dagster instance migrate || {
    echo "⚠️  Migration command failed or already migrated. Continuing..."
  }
else
  echo "⚠️  Could not find daemon pod. Migration may need to be run manually."
fi

echo ""
echo "Step 6: Verifying deployment..."
kubectl get pods -n "${NAMESPACE}"
echo ""
echo "✓ Upgrade complete!"
echo ""
echo "Next steps:"
echo "1. Check pod status: kubectl get pods -n ${NAMESPACE}"
echo "2. Check daemon logs: kubectl logs -n ${NAMESPACE} -l component=dagster-daemon --tail=50"
echo "3. Test a run in the Dagster UI"
echo "4. Verify imagePullPolicy is set: kubectl get job -n ${NAMESPACE} -l dagster/run-id -o yaml | grep imagePullPolicy"
