# Migration Guide: Old Numbered Structure to Unified Hub-and-Spoke

This document describes the final migration from the old numbered directory structure to the unified hub-and-spoke architecture. The old numbered folders (`01-foundation/`, `02-platform/`, `04-deployment/`) and separate `clusters/` and `argocd-apps/` directories have been removed entirely.

## Old vs New Structure

| Old Path | New Path | Reason |
|----------|----------|--------|
| `00-bootstrap/terraform/` | `bootstrap/terraform-backend/` | Clearer naming, no numbered prefix |
| `01-foundation/terraform/` | `infrastructure/shared/` + `infrastructure/hub/` + `infrastructure/spokes/*/` | Split per environment; shared resources separated |
| `02-platform/` | `platform/core/` + `platform/observability/` + `platform/security/` | Organized by concern, not deployment order |
| `02-platform/argocd/` | `platform/core/argocd/` | ArgoCD is a core platform component |
| `02-platform/argocd-apps/` | `gitops/infrastructure/` | GitOps definitions separated from platform manifests |
| `03-application/dagster_project/` | `applications/dagster-project/` | Standard naming convention |
| `04-deployment/` | `platform/dagster/` + `gitops/applications/` | Helm values in platform; ArgoCD apps in gitops |
| `clusters/hub/terraform/` | `infrastructure/hub/` | Unified under infrastructure/ |
| `clusters/spokes/*/terraform/` | `infrastructure/spokes/*/` | Unified under infrastructure/ |
| `clusters/hub/argocd/` | `platform/core/argocd/` | ArgoCD installation in platform/core |
| `clusters/spokes/*/registration/` | `scripts/register-cluster.sh` | Centralized registration script |
| `argocd-apps/hub/` | `gitops/infrastructure/` | App-of-apps and platform apps |
| `argocd-apps/dev/` | `gitops/applications/dev/` | Per-environment Dagster apps |
| `argocd-apps/staging/` | `gitops/applications/staging/` | Per-environment Dagster apps |
| `argocd-apps/prod/` | `gitops/applications/prod/` | Per-environment Dagster apps |

## What Changed

### Infrastructure Consolidation
- **Before**: Infrastructure was split across `01-foundation/`, `clusters/hub/terraform/`, and `clusters/spokes/*/terraform/`
- **After**: All infrastructure lives under `infrastructure/` with clear sub-directories:
  - `infrastructure/shared/` — Cross-cluster resources (Route53, ACM, Cognito, ECR, SNS, CloudWatch)
  - `infrastructure/hub/` — Hub cluster VPC, EKS, IAM
  - `infrastructure/spokes/<env>/` — Per-environment VPC, EKS, RDS, IAM

### Platform Component Reorganization
- **Before**: `02-platform/` contained a flat list of scripts and Helm installs; `clusters/hub/argocd/` had ArgoCD config
- **After**: `platform/` is organized by function:
  - `platform/core/` — Essential components (ArgoCD, ALB Controller, External DNS, External Secrets, Metrics Server)
  - `platform/observability/hub/` — Hub monitoring (Prometheus aggregator, Grafana, Alertmanager)
  - `platform/observability/spoke/` — Spoke monitoring (Prometheus agent, Fluent Bit, OTEL Collector)
  - `platform/dagster/` — Kustomize base + environment overlays + Helm values
  - `platform/security/` — Network policies, pod security, ExternalSecrets

### GitOps Definitions Separated
- **Before**: ArgoCD Application definitions were in `argocd-apps/` (and partially in `02-platform/argocd-apps/`)
- **After**: All GitOps definitions live in `gitops/`:
  - `gitops/infrastructure/app-of-apps.yaml` — Root application
  - `gitops/infrastructure/core-apps.yaml` — Platform core components
  - `gitops/infrastructure/observability-apps.yaml` — Monitoring stack
  - `gitops/applications/<env>/dagster-<env>.yaml` — Per-environment Dagster apps

### Deployment Path Removed
- **Before**: `04-deployment/` contained manual `helm upgrade --install` scripts
- **After**: Dagster deployment is fully GitOps-driven:
  - Helm values in `platform/dagster/helm-values.yaml`
  - Kustomize overlays in `platform/dagster/overlays/<env>/`
  - ArgoCD Application definitions in `gitops/applications/<env>/`

### CI/CD Updated
- **Before**: Workflows referenced `01-foundation/**`, `02-platform/**`, `04-deployment/**`, `clusters/**`, `argocd-apps/**`
- **After**: Workflows reference `bootstrap/**`, `infrastructure/**`, `platform/**`, `applications/**`, `gitops/**`

## Breaking Changes

1. **All old numbered directories removed**: `01-foundation/`, `02-platform/`, `04-deployment/` no longer exist
2. **`clusters/` directory removed**: Replaced by `infrastructure/hub/` and `infrastructure/spokes/`
3. **`argocd-apps/` directory removed**: Replaced by `gitops/`
4. **No more single-cluster mode**: The platform is exclusively hub-and-spoke
5. **CI/CD path filters changed**: All workflows updated to match new directory structure

## Migration Steps

### 1. Backup Existing Data
```bash
# Backup RDS
aws rds create-db-snapshot \
  --db-instance-identifier dagster-platform-rds \
  --db-snapshot-identifier "pre-migration-$(date +%Y%m%d)"

# Backup Terraform state
aws s3 cp s3://your-state-bucket/ ./state-backup/ --recursive
```

### 2. Deploy New Infrastructure
```bash
# Bootstrap (unchanged location)
cd bootstrap/terraform-backend && terraform init && terraform apply

# Deploy shared infrastructure
cd ../../infrastructure/shared && terraform init && terraform apply

# Deploy hub
./scripts/deploy-hub.sh

# Deploy spokes
./scripts/deploy-spoke.sh dev
./scripts/deploy-spoke.sh staging
./scripts/deploy-spoke.sh prod
```

### 3. Apply GitOps Definitions
```bash
# Apply app-of-apps to hub
kubectl apply -f gitops/infrastructure/app-of-apps.yaml --context hub

# Verify all applications sync
kubectl get applications -n argocd --context hub
```

### 4. Verify
```bash
# Run full verification
./scripts/verify-deployment.sh

# Verify Dagster is working on each spoke
for env in dev staging prod; do
  kubectl get pods -n dagster --context ${env}
done
```

### 5. Clean Up Old Resources
```bash
# Remove any old single-cluster deployments
# Only after verifying the new multi-cluster setup is fully operational

# Old Terraform state keys can be removed from S3 if they reference
# the old 01-foundation, 02-platform, or 04-deployment paths
```

## Directory Mapping Quick Reference

```
OLD                              NEW
───                              ───
01-foundation/terraform/    →    infrastructure/shared/ + infrastructure/hub/ + infrastructure/spokes/*/
02-platform/argocd/         →    platform/core/argocd/
02-platform/scripts/        →    (removed — platform installed via ArgoCD)
04-deployment/helm/         →    platform/dagster/helm-values.yaml
04-deployment/scripts/      →    (removed — deployment via ArgoCD)
clusters/hub/               →    infrastructure/hub/ + platform/core/argocd/
clusters/spokes/*/          →    infrastructure/spokes/*/
argocd-apps/hub/            →    gitops/infrastructure/
argocd-apps/dev/            →    gitops/applications/dev/
argocd-apps/staging/        →    gitops/applications/staging/
argocd-apps/prod/           →    gitops/applications/prod/
```
