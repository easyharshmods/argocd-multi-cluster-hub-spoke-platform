# Multi-Cluster GitOps Platform with ArgoCD Hub-and-Spoke Architecture

A production-grade data orchestration platform demonstrating multi-cluster GitOps management, ArgoCD hub-and-spoke architecture, Kustomize overlays for environment promotion, and path-based CI/CD automation on AWS EKS.

## What This Demonstrates

- **Multi-Cluster Hub-and-Spoke**: Central ArgoCD hub managing dev, staging, and production spoke clusters
- **Auto-Registration**: Spoke clusters self-register to the hub on creation
- **Environment Promotion**: Kustomize overlays enable consistent, progressive delivery across environments
- **Path-Based CI/CD**: GitHub Actions triggers only affected components
- **Production Security**: IRSA, Cognito auth, secrets management, network isolation per environment
- **Complete Observability**: Centralized metrics (Prometheus), logs (CloudWatch), traces (X-Ray)
- **Cost Optimization**: Spot instances for dev/staging, on-demand for prod, right-sized hub

## Architecture

```
                        ┌─────────────────┐
                        │   ArgoCD Hub    │
                        │  (dagster-hub)  │
                        └────────┬────────┘
                                 │
           ┌─────────────────────┼─────────────────────┐
           │                     │                     │
           ▼                     ▼                     ▼
     ┌──────────┐         ┌──────────┐         ┌──────────┐
     │   Dev    │         │ Staging  │         │   Prod   │
     │  Spoke   │         │  Spoke   │         │  Spoke   │
     ├──────────┤         ├──────────┤         ├──────────┤
     │ t3.med   │         │ t3.med   │         │ t3.large │
     │ SPOT     │         │ SPOT     │         │ON_DEMAND │
     │ 1-6 nodes│         │ 2-6 nodes│         │3-10 nodes│
     │ auto-sync│         │ auto-sync│         │manual    │
     └──────────┘         └──────────┘         └──────────┘
```

### Deployment Flow

Changes merged to `main` flow automatically through environments:

1. **Dev**: Auto-synced immediately, DEBUG logging
2. **Staging**: Auto-synced with Slack notifications on failure
3. **Production**: Manual sync required, PagerDuty alerts on health degradation

## Repository Structure

```
.
├── bootstrap/                   # Terraform state backend (S3 + KMS)
│   └── terraform-backend/
├── infrastructure/              # All AWS infrastructure (Terraform)
│   ├── shared/                  # Cross-cluster: Route53, ACM, Cognito, ECR, SNS, CloudWatch
│   ├── hub/                     # Hub cluster: VPC, EKS (t3.small), IAM
│   └── spokes/
│       ├── dev/                 # Dev: VPC, EKS (t3.medium SPOT), RDS, IAM
│       ├── staging/             # Staging: VPC, EKS (t3.medium SPOT), RDS, IAM
│       └── prod/                # Prod: VPC, EKS (t3.large ON_DEMAND), RDS (multi-AZ), IAM
├── platform/                    # Kubernetes platform components
│   ├── core/                    # Essential: ArgoCD, ALB Controller, External DNS, External Secrets, Metrics Server
│   │   ├── argocd/
│   │   ├── aws-load-balancer-controller/
│   │   ├── external-dns/
│   │   ├── external-secrets/
│   │   └── metrics-server/
│   ├── observability/           # Monitoring and logging
│   │   ├── hub/                 # Hub: Prometheus (aggregator), Grafana, Alertmanager
│   │   └── spoke/               # Spoke: Prometheus agent, Fluent Bit, OTEL Collector
│   ├── dagster/                 # Dagster deployment
│   │   ├── base/                # Kustomize base manifests
│   │   ├── overlays/dev/
│   │   ├── overlays/staging/
│   │   ├── overlays/prod/
│   │   ├── helm-values.yaml     # Production Helm values
│   │   └── UPGRADE_GUIDE.md
│   ├── security/                # Network policies, pod security, ExternalSecrets
│   ├── monitoring/              # Additional monitoring configs
│   └── helm-values/             # Shared helm values docs
├── applications/                # Application code
│   └── dagster-project/         # Dagster pipelines, assets, sensors
├── gitops/                      # ArgoCD application definitions
│   ├── infrastructure/          # App-of-apps for platform
│   │   ├── app-of-apps.yaml
│   │   ├── core-apps.yaml
│   │   └── observability-apps.yaml
│   └── applications/            # Per-environment Dagster apps
│       ├── dev/dagster-dev.yaml
│       ├── staging/dagster-staging.yaml
│       └── prod/dagster-prod.yaml
├── terraform/                   # Shared Terraform modules
│   └── modules/
│       ├── rds/
│       └── irsa-role/
├── scripts/                     # Automation
├── docs/                        # Documentation
└── .github/workflows/           # CI/CD
```

## Prerequisites

- **AWS CLI** configured with admin-level permissions
- **Terraform** >= 1.10.0
- **kubectl** and **Helm 3**
- **Docker** (for building the Dagster image)
- **Domain**: a DNS domain in Route53

## Quick Start

```bash
# 1. Bootstrap Terraform state backend
cd bootstrap/terraform-backend
terraform init && terraform apply

# 2. Deploy shared infrastructure
cd ../../infrastructure/shared
terraform init && terraform apply

# 3. Deploy hub cluster with ArgoCD
./scripts/deploy-hub.sh

# 4. Deploy spoke clusters (can run in parallel)
./scripts/deploy-spoke.sh dev
./scripts/deploy-spoke.sh staging
./scripts/deploy-spoke.sh prod

# 5. Apply ArgoCD app-of-apps
kubectl apply -f gitops/infrastructure/app-of-apps.yaml --context hub

# 6. Verify
./scripts/verify-deployment.sh
```

## Post-Deployment

### Access ArgoCD (Hub)
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 --context hub
# Open https://localhost:8080
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' --context hub | base64 -d
```

### Access Dagster UI
```bash
# Dev
open https://dagster-dev.example.com

# Staging
open https://dagster-staging.example.com

# Production
open https://dagster.example.com
```

### Access Grafana (Hub)
```bash
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80 --context hub
# Open http://localhost:3000 — credentials: admin / dagster-admin
```

## Environment Comparison

| Setting | Dev | Staging | Prod |
|---------|-----|---------|------|
| Webserver replicas | 1 | 2 | 3 |
| Daemon replicas | 1 | 1 | 2 |
| Instance type | t3.medium | t3.medium | t3.large |
| Capacity type | SPOT | SPOT | ON_DEMAND |
| Node range | 1-6 | 2-6 | 3-10 |
| ArgoCD sync | Auto | Auto | Manual |
| Log level | DEBUG | INFO | INFO |
| Image tag | dev-latest | staging-latest | Pinned version |
| Resource quotas | None | None | CPU: 10/20, Memory: 20Gi/40Gi |

## CI/CD

GitHub Actions workflows provide path-based validation:

| Path Changed | Validation |
|-------------|------------|
| `bootstrap/**` | Terraform validate + fmt |
| `infrastructure/shared/**` | Terraform validate + fmt |
| `infrastructure/hub/**` | Terraform validate + fmt |
| `infrastructure/spokes/dev/**` | Terraform validate + fmt |
| `infrastructure/spokes/staging/**` | Terraform validate |
| `infrastructure/spokes/prod/**` | Terraform validate |
| `platform/**` | Kustomize overlay validation |
| `applications/**` | Ruff lint + pytest + Docker build |
| `gitops/**` | YAML dry-run validation |

Production deployments require manual approval via GitHub Environments.

## Documentation

- [Architecture](docs/ARCHITECTURE.md) — System architecture with Mermaid diagrams
- [Hub-and-Spoke Pattern](docs/HUB_SPOKE_PATTERN.md) — Design rationale and implementation details
- [Multi-Cluster Operations](docs/MULTI_CLUSTER.md) — Deployment guide, adding/removing environments, cost model
- [Troubleshooting](docs/TROUBLESHOOTING.md) — Common issues and resolution steps
- [Migration Guide](docs/MIGRATION_FROM_OLD_STRUCTURE.md) — Migration from old numbered directory structure

## Versions

| Component | Version |
|-----------|---------|
| Terraform | >= 1.10.0 |
| Kubernetes / EKS | 1.34 |
| Dagster | 1.12.14 |
| ArgoCD | 7.7.5 |
| AWS Load Balancer Controller | 1.11.0 |
| External DNS | 1.20.0 |
| External Secrets Operator | 0.12.1 |
| kube-prometheus-stack | 65.4.0 |
| Fluent Bit | 3.2.1 |
| ADOT Collector | v0.46.0 |
| RDS PostgreSQL | 17.2 |
| Python | 3.12 |

## Cleanup

```bash
# Destroy in reverse order

# 1. Remove ArgoCD applications
kubectl delete -f gitops/ --recursive --context hub

# 2. Destroy spoke clusters
cd infrastructure/spokes/prod && terraform destroy
cd ../staging && terraform destroy
cd ../dev && terraform destroy

# 3. Destroy hub cluster
cd ../../hub && terraform destroy

# 4. Destroy shared infrastructure
cd ../shared && terraform destroy

# 5. Destroy bootstrap (optional)
cd ../../bootstrap/terraform-backend && terraform destroy
```

## License

See [LICENSE](LICENSE).
