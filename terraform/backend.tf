# Uncomment to use S3 backend for state management
# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "serverless-app/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "terraform-locks"
#   }
# }
