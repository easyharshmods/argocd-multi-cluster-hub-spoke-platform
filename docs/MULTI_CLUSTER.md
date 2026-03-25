# Multi-Cluster Operations Guide

## Cluster Inventory

| Cluster | Role | VPC CIDR | Instance Type | Capacity | Purpose |
|---------|------|----------|---------------|----------|---------|
| dagster-hub | Hub | 10.0.0.0/16 | t3.small (SPOT) | 2-4 nodes | ArgoCD, monitoring aggregation |
| dagster-dev | Spoke | 10.10.0.0/16 | t3.medium (SPOT) | 1-6 nodes | Development workloads |
| dagster-staging | Spoke | 10.20.0.0/16 | t3.medium (SPOT) | 2-6 nodes | Pre-production validation |
| dagster-prod | Spoke | 10.30.0.0/16 | t3.large (ON_DEMAND) | 3-10 nodes | Production workloads |

## Deployment Order

```
1. Bootstrap          → S3 + KMS for Terraform state
2. Shared Infra       → Route53, ACM, Cognito, ECR, SNS, CloudWatch
3. Hub Cluster        → EKS + ArgoCD installation
4. Spoke Clusters     → EKS + auto-registration to hub
5. GitOps Apps        → Application definitions applied to hub
6. ArgoCD syncs       → Dagster deployed to each spoke automatically
```

### Step-by-Step

```bash
# 1. Bootstrap (if not already done)
cd bootstrap/terraform-backend && terraform init && terraform apply

# 2. Deploy shared infrastructure
cd ../../infrastructure/shared && terraform init && terraform apply

# 3. Deploy hub
./scripts/deploy-hub.sh

# 4. Deploy spokes (can run in parallel)
./scripts/deploy-spoke.sh dev
./scripts/deploy-spoke.sh staging
./scripts/deploy-spoke.sh prod

# 5. Apply ArgoCD app definitions
kubectl apply -f gitops/infrastructure/app-of-apps.yaml --context hub

# 6. Verify
./scripts/verify-deployment.sh
```

## kubectl Context Management

After deployment, you'll have multiple kubectl contexts:

```bash
# List all contexts
kubectl config get-contexts

# Switch between clusters
kubectl config use-context hub
kubectl config use-context dev
kubectl config use-context staging
kubectl config use-context prod

# Run commands against specific cluster
kubectl get pods -n dagster --context dev
kubectl get pods -n dagster --context prod
kubectl get applications -n argocd --context hub
```

## Adding a New Environment

To add a new spoke (e.g., `qa`):

1. Copy an existing spoke directory:
   ```bash
   cp -r infrastructure/spokes/dev infrastructure/spokes/qa
   ```

2. Update the Terraform configuration:
   - `main.tf`: Change `cluster_name` to `dagster-qa`, `vpc_cidr` to a new CIDR
   - `eks.tf`: Adjust node sizing as needed

3. Create a Kustomize overlay:
   ```bash
   cp -r platform/dagster/overlays/dev platform/dagster/overlays/qa
   ```
   Update the `kustomization.yaml` with QA-specific configuration.

4. Create an ArgoCD Application:
   ```bash
   mkdir -p gitops/applications/qa
   ```
   Create `dagster-qa.yaml` pointing to the new overlay and `dagster-qa` cluster.

5. Deploy:
   ```bash
   ./scripts/deploy-spoke.sh qa
   kubectl apply -f gitops/applications/qa/ --context hub
   ```

## Removing a Spoke

```bash
# 1. Remove ArgoCD application
kubectl delete application dagster-<env> -n argocd --context hub

# 2. Remove cluster registration
kubectl delete secret cluster-dagster-<env> -n argocd --context hub

# 3. Destroy spoke infrastructure
cd infrastructure/spokes/<env>
terraform destroy

# 4. Clean up kubectl context
kubectl config delete-context <env>
```

## Cost Estimation

| Component | Monthly Cost (estimate) |
|-----------|------------------------|
| Hub cluster (2x t3.small spot) | ~$15 |
| Dev spoke (2x t3.medium spot) | ~$30 |
| Staging spoke (3x t3.medium spot) | ~$45 |
| Prod spoke (3x t3.large on-demand) | ~$200 |
| RDS per environment (db.t3.micro) | ~$15 each |
| NAT Gateway per VPC | ~$35 each |
| **Total (all environments)** | **~$450/month** |

## Monitoring Across Clusters

The hub cluster aggregates metrics from all spokes:

- **Prometheus**: Each spoke runs a Prometheus agent (`platform/observability/spoke/`) that remote-writes metrics to the hub's Prometheus (`platform/observability/hub/`)
- **Grafana**: Dashboards on the hub show metrics from all environments in a single view
- **CloudWatch**: Each spoke ships logs to its own CloudWatch log group via Fluent Bit
- **X-Ray**: Traces from all environments appear in the same AWS X-Ray console (filtered by environment tag)
