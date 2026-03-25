# Bootstrap: Terraform State Backend

## Purpose
Creates a secure S3 backend for Terraform state storage with KMS encryption and native S3 locking. This is the first layer deployed and provides the foundation for all subsequent Terraform operations.

## Why This Approach?
- **S3 native locking** (Terraform 1.10+): Eliminates the need for a separate DynamoDB table, reducing infrastructure complexity and cost
- **KMS encryption**: All state files are encrypted at rest using a dedicated KMS key with automatic rotation
- **Versioning**: S3 versioning enables state recovery if corruption occurs
- **Lifecycle policies**: Old state versions are automatically cleaned up after 90 days

## Prerequisites
- AWS CLI configured with admin-level permissions
- Terraform >= 1.10.0

## Deployment
```bash
cd bootstrap/terraform-backend
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## Outputs
- Creates `infrastructure/shared/bootstrap.auto.tfvars` automatically
- Contains: S3 bucket name, KMS key ID, AWS account ID

## Validation
```bash
# Verify S3 bucket exists
aws s3 ls s3://$(terraform output -raw s3_bucket_name)

# Verify KMS key
aws kms describe-key --key-id $(terraform output -raw kms_key_id) --query 'KeyMetadata.KeyState'
```

## Time
~2-3 minutes

## Troubleshooting

### "BucketAlreadyOwnedByYou" error
The S3 bucket uses a random suffix for global uniqueness. If you see this error, the bucket already exists in your account — run `terraform import` to adopt it.

### KMS key in "PendingDeletion" state
If a previous destroy scheduled the KMS key for deletion, cancel it:
```bash
aws kms cancel-key-deletion --key-id <key-id>
aws kms enable-key --key-id <key-id>
```
