# terraform-runner-infra/main/backend.tf

terraform {
  backend "s3" {
    # These values should match your existing state bucket configuration
    # but with a different key for the runner infrastructure
    
    bucket = "your-terraform-state-bucket-name"           # Replace with your actual bucket
    key    = "runner-infra/terraform.tfstate"             # Different path from main project
    region = "us-east-1"                                  # Replace with your bucket region
    
    # Optional: State locking with DynamoDB
    dynamodb_table = "your-terraform-state-lock-table"    # Replace with your table name
    encrypt        = true
    
    # Optional: For better security, you can specify the KMS key
    # kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/your-key-id"
  }
}

# Note: Update the bucket, region, and dynamodb_table values above to match 
# your existing Terraform state configuration from the main project.
