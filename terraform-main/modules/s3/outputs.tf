# terraform-main/modules/s3/outputs.tf

output "bucket_arn" {
  description = "ARN of the S3 bucket for application data"
  value       = aws_s3_bucket.app_data.arn
}

output "bucket_id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.app_data.id
}

output "bucket_policy_resource_id" {
  description = "Resource ID for the bucket policy that can be referenced by other modules"
  value       = aws_s3_bucket_policy.base_restrictive.id
}
