#!/bin/bash
set -euo pipefail

# Register an existing spoke cluster to the ArgoCD hub
# Usage: ./register-cluster.sh <environment> [hub-cluster-name]

ENVIRONMENT="${1:-}"
HUB_CLUSTER_NAME="${2:-dagster-hub}"

if [ -z "${ENVIRONMENT}" ]; then
  echo "Usage: $0 <environment> [hub-cluster-name]"
  echo "Example: $0 dev dagster-hub"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Registering ${ENVIRONMENT} cluster to hub (${HUB_CLUSTER_NAME})..."

cd "${PROJECT_ROOT}/infrastructure/spokes/${ENVIRONMENT}/registration"

export ENVIRONMENT="${ENVIRONMENT}"
export HUB_CLUSTER_NAME="${HUB_CLUSTER_NAME}"
./register.sh
