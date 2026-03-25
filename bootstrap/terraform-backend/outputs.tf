output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "s3_bucket_region" {
  description = "Region of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.region
}

output "kms_key_id" {
  description = "ID of the KMS key for encryption"
  value       = aws_kms_key.terraform_state.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key"
  value       = aws_kms_key.terraform_state.arn
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = data.aws_region.current.name
}

# Write outputs to file for infrastructure/shared to consume
resource "local_file" "outputs_for_foundation" {
  filename = "${path.module}/../../infrastructure/shared/bootstrap.auto.tfvars"
  content  = <<-EOT
    # Auto-generated from bootstrap/terraform-backend
    # DO NOT EDIT MANUALLY

    tfstate_bucket_name = "${aws_s3_bucket.terraform_state.id}"
    tfstate_kms_key_id  = "${aws_kms_key.terraform_state.id}"
    aws_account_id      = "${data.aws_caller_identity.current.account_id}"
  EOT

  file_permission = "0644"
}
