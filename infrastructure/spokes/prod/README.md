# Production Spoke Cluster

Production environment spoke cluster for running Dagster production workloads.

## Characteristics

- **Purpose**: Production workloads with high availability
- **Instance Type**: t3.large ON_DEMAND instances (no spot interruptions)
- **Auto-scaling**: 3-10 nodes
- **Managed By**: ArgoCD hub cluster
- **Availability**: High availability with dedicated on-demand capacity

## Deployment

```bash
# From project root
./scripts/deploy-spoke.sh prod
```

This will:
1. Deploy EKS cluster via Terraform
2. Configure kubectl access
3. Auto-register to hub ArgoCD
4. Hub deploys Dagster to this cluster

## Auto-Registration

The spoke automatically registers itself to the hub cluster on creation.
See: `registration/register.sh`

## Production Considerations

- Uses **ON_DEMAND** instances to avoid spot interruptions
- Minimum 3 nodes for high availability
- Scales up to 10 nodes under load
- Larger instance type (t3.large) for production workloads

## Access

```bash
# Configure kubectl
aws eks update-kubeconfig --name dagster-prod --region eu-central-1 --alias prod

# View pods
kubectl get pods -n dagster --context prod
```
