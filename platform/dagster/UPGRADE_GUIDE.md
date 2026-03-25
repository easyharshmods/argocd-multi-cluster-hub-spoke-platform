# Dagster Upgrade Guide: 1.9.11 → 1.12.14

## Prerequisites
- ✅ All files have been updated (requirements.txt, pyproject.toml, Helm values, deploy.sh)
- ✅ You have AWS CLI access
- ✅ You have kubectl access to the EKS cluster

## Step 1: Backup RDS Database

**CRITICAL**: Backup your database before upgrading!

```bash
# Get your RDS instance identifier from foundation.env or AWS Console
source foundation.env
RDS_INSTANCE_ID=$(aws rds describe-db-instances \
  --region ${AWS_REGION} \
  --query 'DBInstances[?contains(DBInstanceIdentifier, `dagster`)].DBInstanceIdentifier' \
  --output text | head -1)

echo "RDS Instance: ${RDS_INSTANCE_ID}"

# Create snapshot
aws rds create-db-snapshot \
  --db-instance-identifier "${RDS_INSTANCE_ID}" \
  --db-snapshot-identifier "dagster-pre-upgrade-$(date +%Y%m%d-%H%M%S)" \
  --region "${AWS_REGION}"

echo "Snapshot created. Wait for it to complete:"
aws rds describe-db-snapshots \
  --db-snapshot-identifier "dagster-pre-upgrade-$(date +%Y%m%d-%H%M%S)" \
  --region "${AWS_REGION}" \
  --query 'DBSnapshots[0].Status'
```

**Wait for snapshot status to be "available" before proceeding.**

## Step 2: Rebuild User Code Image

Rebuild the Docker image with Dagster 1.12.14:

```bash
cd applications/dagster-project
./build-push.sh
```

This will:
- Install Dagster 1.12.14 and dependencies
- Build new Docker image
- Push to ECR

**Note the new IMAGE_URI** from the output or check `platform/dagster/application.env`.

## Step 3: Update Helm Repo

```bash
cd ../../platform/dagster
helm repo add dagster https://dagster-io.github.io/helm 2>/dev/null || true
helm repo update
```

Verify the new version is available:
```bash
helm search repo dagster/dagster --versions | head -5
```

Should show `1.12.14` as available.

## Step 4: Upgrade Helm Deployment

```bash
# Ensure you're in 04-deployment directory
cd platform/dagster

# Load environment variables
source foundation.env
source application.env

# Verify IMAGE_URI is updated (should point to new image)
echo "Using image: ${IMAGE_URI}"

# Upgrade Helm release
HELM_SKIP_WAIT=1 ./scripts/deploy.sh
```

This will:
- Upgrade Helm chart to 1.12.14
- Update webserver/daemon images to 1.12.14
- Deploy new user code image

## Step 5: Wait for Pods to be Ready

```bash
# Watch pod status
kubectl get pods -n dagster -w

# Or check status
kubectl get pods -n dagster
```

Wait for:
- `dagster-dagster-webserver-*` pods: `Running` (2/2 ready)
- `dagster-dagster-daemon-*` pod: `Running` (1/1 ready)
- `dagster-dagster-user-deployments-user-code-*` pod: `Running` (1/1 ready)

## Step 6: Restart Daemon (if needed)

```bash
./scripts/restart-daemon.sh
```

## Step 7: Run Database Migration

Dagster 1.12.14 may require database schema updates:

```bash
# Get daemon pod name
DAEMON_POD=$(kubectl get pods -n dagster -l "component=dagster-daemon" -o jsonpath='{.items[0].metadata.name}')

# Run migration
kubectl exec -n dagster "${DAEMON_POD}" -- dagster instance migrate
```

Expected output:
- `Instance is up to date` (if already migrated)
- Or migration steps will run automatically

## Step 8: Verify Upgrade

### Check versions:
```bash
# Check Helm release version
helm list -n dagster

# Check pod images
kubectl get pods -n dagster -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

Should show:
- Helm chart: `1.12.14`
- Pod images: `dagster/dagster-k8s:1.12.14`
- User code: Your ECR image with Dagster 1.12.14

### Check daemon logs:
```bash
kubectl logs -n dagster -l component=dagster-daemon --tail=50
```

Look for:
- No errors about version mismatches
- Successful connection to user code
- No migration errors

## Step 9: Test a Run

1. **Open Dagster UI**: https://dagster.<your-domain> (or your domain)
2. **Login via Cognito**
3. **Start a simple run**: Try `greeting_asset` or `random_numbers`
4. **Verify no 422 error**: The `imagePullPolicy: "<no value>"` error should be gone!

### Check Job YAML:
```bash
# After starting a run, check the Job
kubectl get job -n dagster -l dagster/run-id --sort-by=.metadata.creationTimestamp | tail -1
JOB_NAME=$(kubectl get job -n dagster -l dagster/run-id --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')
kubectl get job -n dagster "${JOB_NAME}" -o yaml | grep -A5 imagePullPolicy
```

Should show: `imagePullPolicy: Always` (not `<no value>`)

## Troubleshooting

### Pods stuck in Init or CrashLoopBackOff:
- Check logs: `kubectl logs -n dagster <pod-name>`
- Check events: `kubectl describe pod -n dagster <pod-name>`
- Verify RDS connectivity still works

### Migration errors:
- Check daemon logs: `kubectl logs -n dagster -l component=dagster-daemon --tail=100`
- Verify RDS credentials: `kubectl get secret -n dagster dagster-postgresql-secret -o yaml`

### Still seeing imagePullPolicy errors:
- Verify Helm values were applied: `helm get values dagster -n dagster | grep -A10 runK8sConfig`
- Check asset tags are present in code
- Restart daemon: `./scripts/restart-daemon.sh`

### Rollback (if needed):
```bash
# Rollback Helm release
helm rollback dagster -n dagster

# Or reinstall previous version
helm upgrade --install dagster dagster/dagster \
  --namespace dagster \
  --version 1.9.11 \
  -f helm/dagster-values.yaml \
  # ... (rest of your deploy.sh args)
```

## Success Criteria

✅ All pods running
✅ No errors in daemon logs
✅ Can start runs without 422 errors
✅ Jobs have `imagePullPolicy: Always` set correctly
✅ Dagster UI shows all assets

## Breaking Changes in 1.12.0+

- **FreshnessPolicy**: Moved to top-level `dagster` module (if you use it)
- **FreshnessDaemon**: Now runs by default (can disable in dagster.yaml)
- **Custom Executors**: May need updates for resource initialization

If you use any of these features, check the [Dagster upgrade guide](https://docs.dagster.io/migration/upgrading).
