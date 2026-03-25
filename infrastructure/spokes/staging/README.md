# Staging Spoke Cluster

Staging environment spoke cluster for pre-production Dagster workloads.

## Characteristics

- **Purpose**: Pre-production testing and validation
- **Instance Type**: t3.medium spot instances
- **Auto-scaling**: 2-6 nodes
- **Managed By**: ArgoCD hub cluster
- **Cost**: ~$75/month with spot instances

## Deployment

```bash
# From project root
./scripts/deploy-spoke.sh staging
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
aws eks update-kubeconfig --name dagster-staging --region eu-central-1 --alias staging

# View pods
kubectl get pods -n dagster --context staging
```
