# modules/kms/outputs.tf

output "kms_key_arn" {
  description = "The Amazon Resource Name (ARN) of the key"
  value       = aws_kms_key.s3_key.arn
}
