# Hub-and-Spoke Pattern

## Overview

This platform uses a hub-and-spoke architecture where a central hub cluster running ArgoCD manages multiple spoke clusters across environments (dev, staging, production).

## Why Hub-and-Spoke?

### Single Pane of Glass
One ArgoCD instance provides visibility into all environments. Operators can see deployment status, sync state, and health across dev, staging, and production from a single dashboard.

### Consistent Deployments
The same Kustomize base is used across all environments, with overlays for environment-specific configuration. This eliminates configuration drift between environments.

### Progressive Delivery
Changes flow from dev → staging → prod with increasing gates:
- **Dev**: Auto-sync on every push to `main`
- **Staging**: Auto-sync with Slack notifications on failure
- **Prod**: Manual sync required, PagerDuty alerts on degraded health

### Cost Optimization
The hub cluster is small (t3.small spot instances) since it only runs ArgoCD and monitoring aggregation. Spoke clusters are sized per environment needs.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Git Repository                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ infra-   │  │ platform/│  │ gitops/  │  │ apps/    │   │
│  │ structure/│  │ dagster/ │  │ applica- │  │ dagster- │   │
│  │ hub/     │  │ overlays/│  │ tions/   │  │ project/ │   │
│  │ spokes/  │  └──────────┘  │ dev/     │  └──────────┘   │
│  └──────────┘                │ staging/ │                  │
│                               │ prod/    │                  │
│                               └──────────┘                  │
└──────────────────────┬──────────────────────────────────────┘
                       │ watches
                       ▼
┌──────────────────────────────────────────────────────────────┐
│                    Hub Cluster (dagster-hub)                  │
│                                                              │
│  ┌──────────────┐  ┌──────────┐  ┌────────────────────┐    │
│  │   ArgoCD     │  │ Prometheus│  │ Grafana            │    │
│  │  (7.7.5)     │  │ (agg.)   │  │ (unified dashboard)│    │
│  └──────┬───────┘  └──────────┘  └────────────────────┘    │
│         │                                                    │
│    manages 3 spokes                                          │
└─────────┼────────────────────────────────────────────────────┘
          │
    ┌─────┼─────────────────────┐
    │     │                     │
    ▼     ▼                     ▼
┌────────┐ ┌──────────┐ ┌──────────┐
│  Dev   │ │ Staging  │ │   Prod   │
│ Spoke  │ │  Spoke   │ │  Spoke   │
├────────┤ ├──────────┤ ├──────────┤
│t3.med  │ │ t3.med   │ │ t3.large │
│SPOT    │ │ SPOT     │ │ON_DEMAND │
│1-6 node│ │ 2-6 node │ │3-10 node │
│auto-   │ │ auto-    │ │ manual   │
│sync    │ │ sync     │ │ sync     │
└────────┘ └──────────┘ └──────────┘
```

## Spoke Registration

When a new spoke cluster is deployed, it auto-registers to the hub:

1. **Terraform** provisions the EKS cluster (`infrastructure/spokes/<env>/`)
2. **register.sh** creates a ServiceAccount in the spoke with cluster-admin permissions
3. The script creates a Kubernetes Secret in the hub's `argocd` namespace with the spoke's connection details
4. ArgoCD discovers the new cluster and begins syncing applications

See `scripts/register-cluster.sh` for the implementation.

## Kustomize Overlays

The platform uses Kustomize to manage environment-specific configuration:

```
platform/dagster/
├── base/                    # Shared Dagster manifests
│   ├── kustomization.yaml
│   ├── dagster-deployment.yaml
│   ├── dagster-service.yaml
│   ├── dagster-ingress.yaml
│   └── dagster-external-secret.yaml
└── overlays/
    ├── dev/                 # 1 webserver, 1 daemon, DEBUG logging
    ├── staging/             # 2 webservers, 1 daemon, INFO logging
    └── prod/                # 3 webservers, 2 daemons, resource quotas
```

## ArgoCD Application Hierarchy

```
app-of-apps (gitops/infrastructure/app-of-apps.yaml)
├── core-apps         → platform/core/*                     → hub + all spokes
├── observability-apps → platform/observability/*            → hub + spokes
├── dagster-dev       → platform/dagster/overlays/dev       → dagster-dev cluster
├── dagster-staging   → platform/dagster/overlays/staging   → dagster-staging cluster
└── dagster-prod      → platform/dagster/overlays/prod      → dagster-prod cluster
```

## Security Model

- **Hub**: Only ArgoCD operators have access. Spoke credentials are stored as ArgoCD cluster secrets.
- **Spokes**: ArgoCD has cluster-admin via a dedicated ServiceAccount. Human operators have read-only by default.
- **IRSA**: Each spoke uses IAM Roles for Service Accounts — no long-lived AWS credentials. IAM roles defined in `infrastructure/spokes/<env>/`.
- **Secrets**: RDS credentials stay in AWS Secrets Manager, synced to K8s via External Secrets Operator per spoke. See `platform/security/` for ExternalSecret definitions.

## Network Isolation

Each environment runs in its own VPC with non-overlapping CIDRs:

| Environment | VPC CIDR |
|------------|----------|
| Hub | 10.0.0.0/16 |
| Dev | 10.10.0.0/16 |
| Staging | 10.20.0.0/16 |
| Prod | 10.30.0.0/16 |

Cross-cluster communication flows through the ArgoCD hub's API server only — spoke clusters do not communicate directly with each other.
