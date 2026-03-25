# Troubleshooting Guide

## Hub Cluster Issues

### ArgoCD pods not starting
```bash
kubectl describe pods -n argocd --context hub
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --context hub
```

### ArgoCD UI not accessible
```bash
# Port-forward for local access
kubectl port-forward svc/argocd-server -n argocd 8080:443 --context hub

# Check Ingress (if using ALB)
kubectl get ingress -n argocd --context hub
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --context hub
```

### ArgoCD running out of memory
The application controller may OOM with many applications. Increase limits in `platform/core/argocd/values.yaml`:
```yaml
controller:
  resources:
    limits:
      memory: 2Gi
```

## Spoke Registration Issues

### Spoke not appearing in ArgoCD
```bash
# Check cluster secret exists
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster --context hub

# Check ArgoCD controller logs for connection errors
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --context hub | grep -i "cluster"

# Re-run registration
ENVIRONMENT=<env> ./scripts/register-cluster.sh
```

### Registration script fails with "Unauthorized"
The hub cluster context may have expired. Refresh it:
```bash
aws eks update-kubeconfig --name dagster-hub --region eu-central-1 --alias hub
```

### "TLS handshake error" when connecting to spoke
The spoke CA data may be incorrect. Verify:
```bash
# Get current CA from spoke
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' --context <env>

# Compare with what's stored in ArgoCD
kubectl get secret cluster-dagster-<env> -n argocd --context hub -o jsonpath='{.data.config}' | base64 -d | jq .
```

## Application Sync Issues

### Application stuck in "OutOfSync"
```bash
# Check what's different
argocd app diff dagster-<env>

# Force sync
argocd app sync dagster-<env> --force

# Check for webhook issues
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --context hub | grep webhook
```

### Application shows "Healthy" but pods are not running
ArgoCD health checks may not cover all resources. Check directly:
```bash
kubectl get pods -n dagster --context <env>
kubectl describe pods -n dagster --context <env>
```

### Sync fails with "namespace not found"
Ensure `CreateNamespace=true` is in the Application's syncOptions:
```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
```

Check the ArgoCD Application definition in `gitops/applications/<env>/dagster-<env>.yaml`.

## Dagster Issues

### Dagster webserver not starting
```bash
kubectl logs -n dagster -l component=dagster-webserver --context <env>
kubectl describe pod -n dagster -l component=dagster-webserver --context <env>
```

Common causes:
- RDS not reachable (check security groups in `infrastructure/spokes/<env>/`)
- ExternalSecret not synced (check External Secrets Operator, see `platform/security/`)
- User code pod crashing (check user-code logs)

### Dagster runs failing with imagePullPolicy error
Ensure `pullPolicy: Always` is set in all image references. See `platform/dagster/helm-values.yaml` for the Helm values and `platform/dagster/overlays/<env>/` for per-environment overrides.

### Database migration needed after upgrade
```bash
DAEMON_POD=$(kubectl get pods -n dagster --context <env> -l component=dagster-daemon -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n dagster --context <env> "${DAEMON_POD}" -- dagster instance migrate
```

See `platform/dagster/UPGRADE_GUIDE.md` for detailed upgrade procedures.

## Terraform Issues

### State lock contention
If Terraform reports a state lock, check if another process is running:
```bash
terraform force-unlock <LOCK_ID>
```

### "EntityAlreadyExists" for IAM resources
Import existing resources into state:
```bash
terraform import <resource_address> <resource_id>
```

Infrastructure Terraform is organized under `infrastructure/`:
- `infrastructure/shared/` — shared resources (Route53, ACM, Cognito, ECR)
- `infrastructure/hub/` — hub cluster resources
- `infrastructure/spokes/<env>/` — per-environment spoke resources

## Network Issues

### Pods cannot reach external services
Check NAT Gateway:
```bash
kubectl run debug --rm -it --image=busybox --context <env> -- wget -qO- https://httpbin.org/ip
```

### Cross-cluster communication failing
Spokes should not communicate directly. All management flows through the hub's ArgoCD. If you need cross-cluster communication, consider VPC peering or Transit Gateway.

## CI/CD Issues

### GitHub Actions workflow not triggering
Check that the paths-filter matches your changed files:
```bash
git diff --name-only main..HEAD
```

Path filters are configured in `.github/workflows/ci.yaml`:
- `bootstrap/**`
- `infrastructure/**`
- `platform/**`
- `applications/**`
- `gitops/**`

### ArgoCD sync in CI fails with authentication error
Verify the `ARGOCD_PASSWORD` secret is set in GitHub repository settings under Settings > Secrets > Actions.
