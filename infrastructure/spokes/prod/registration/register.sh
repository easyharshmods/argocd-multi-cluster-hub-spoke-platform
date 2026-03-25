#!/bin/bash
set -euo pipefail

# Auto-registration script for spoke clusters to ArgoCD hub
# Runs after spoke cluster is ready

ENVIRONMENT="${ENVIRONMENT:-prod}"
HUB_ARGOCD_URL="${HUB_ARGOCD_URL:-https://argocd.example.com}"
SPOKE_CLUSTER_NAME="${SPOKE_CLUSTER_NAME:-dagster-${ENVIRONMENT}}"
HUB_CLUSTER_NAME="${HUB_CLUSTER_NAME:-dagster-hub}"
AWS_REGION="${AWS_REGION:-eu-central-1}"

echo "==================================================================="
echo "Registering spoke cluster: ${SPOKE_CLUSTER_NAME}"
echo "Hub ArgoCD URL: ${HUB_ARGOCD_URL}"
echo "Environment: ${ENVIRONMENT}"
echo "==================================================================="

# 1. Get spoke cluster credentials
echo ">>> Step 1: Retrieving spoke cluster credentials..."
SPOKE_SERVER=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')
SPOKE_CA=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

echo "Spoke server: ${SPOKE_SERVER}"

# 2. Create service account for ArgoCD in spoke
echo ">>> Step 2: Creating ArgoCD service account in spoke cluster..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argocd-manager
  namespace: kube-system
---
apiVersion: v1
kind: Secret
metadata:
  name: argocd-manager-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: argocd-manager
type: kubernetes.io/service-account-token
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argocd-manager-role
rules:
- apiGroups: ['*']
  resources: ['*']
  verbs: ['*']
- nonResourceURLs: ['*']
  verbs: ['*']
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-manager-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argocd-manager-role
subjects:
- kind: ServiceAccount
  name: argocd-manager
  namespace: kube-system
EOF

# Wait for token to be created
echo "Waiting for service account token..."
sleep 5

# 3. Get the bearer token
BEARER_TOKEN=$(kubectl get secret -n kube-system argocd-manager-token -o jsonpath='{.data.token}' | base64 -d)

echo ">>> Step 3: Bearer token retrieved (length: ${#BEARER_TOKEN})"

# 4. Create cluster secret for ArgoCD hub
echo ">>> Step 4: Creating cluster registration secret..."
cat > /tmp/cluster-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cluster-${SPOKE_CLUSTER_NAME}
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
    environment: ${ENVIRONMENT}
type: Opaque
stringData:
  name: ${SPOKE_CLUSTER_NAME}
  server: ${SPOKE_SERVER}
  config: |
    {
      "bearerToken": "${BEARER_TOKEN}",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "${SPOKE_CA}"
      }
    }
EOF

# 5. Apply to hub cluster
echo ">>> Step 5: Registering with hub ArgoCD..."
aws eks update-kubeconfig --name "${HUB_CLUSTER_NAME}" --region "${AWS_REGION}" --alias hub
kubectl apply -f /tmp/cluster-secret.yaml --context hub

# Clean up
rm /tmp/cluster-secret.yaml

echo "==================================================================="
echo "Successfully registered ${SPOKE_CLUSTER_NAME} to ArgoCD hub"
echo "==================================================================="

# 6. Verify registration
echo ">>> Step 6: Verifying registration..."
kubectl get secret -n argocd "cluster-${SPOKE_CLUSTER_NAME}" --context hub

echo "Registration complete! Check ArgoCD UI: ${HUB_ARGOCD_URL}"
