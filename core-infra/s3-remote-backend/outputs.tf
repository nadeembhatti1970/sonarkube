output "state_bucket_name" {
  description = "Name of the S3 bucket that stores Terraform remote state."
  value       = aws_s3_bucket.tfstate.id
}

output "state_bucket_arn" {
  description = "ARN of the Terraform remote state bucket."
  value       = aws_s3_bucket.tfstate.arn
}

output "state_access_logs_bucket_name" {
  description = "Name of the S3 bucket that receives server access logs for the state bucket."
  value       = aws_s3_bucket.state_access_logs.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt Terraform state."
  value       = aws_kms_key.tfstate.arn
}

output "kms_key_alias" {
  description = "Alias of the KMS key used to encrypt Terraform state (set as kms_key_id in dev.tfbackend)."
  value       = aws_kms_alias.tfstate.name
}

output "backend_configuration" {
  description = "Values to place in each root module's dev.tfbackend file."
  value = {
    bucket       = aws_s3_bucket.tfstate.id
    region       = var.aws_region
    encrypt      = true
    use_lockfile = true
    kms_key_id   = aws_kms_alias.tfstate.name
  }
}
