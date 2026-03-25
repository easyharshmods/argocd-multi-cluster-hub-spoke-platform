# Dev Spoke Cluster

Development environment spoke cluster for running Dagster workloads.

## Characteristics

- **Purpose**: Development and testing
- **Instance Type**: t3.medium spot instances
- **Auto-scaling**: 1-6 nodes
- **Managed By**: ArgoCD hub cluster
- **Cost**: ~$50/month with spot instances

## Deployment

```bash
# From project root
./scripts/deploy-spoke.sh dev
```

This will:
1. Deploy EKS cluster via Terraform
2. Configure kubectl access
3. Auto-register to hub ArgoCD
4. Hub deploys Dagster to this cluster

## Auto-Registration

The spoke automatically registers itself to the hub cluster on creation.
See: `registration/register.sh`

## Access

```bash
# Configure kubectl
aws eks update-kubeconfig --name dagster-dev --region eu-central-1 --alias dev

# View pods
kubectl get pods -n dagster --context dev
```
