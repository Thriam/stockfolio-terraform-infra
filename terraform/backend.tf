# Remote Backend Configuration for Stockfolio
# Uses S3 for state storage and DynamoDB for state locking

terraform {
  backend "s3" {
    bucket         = "stockfolio-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "stockfolio-terraform-locks"
  }
}

