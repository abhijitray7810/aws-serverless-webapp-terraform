output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "api_gateway_endpoint" {
  description = "API Gateway endpoint"
  value       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${var.aws_region}.amazonaws.com/${local.environment}/items"
}

output "s3_website_bucket" {
  description = "S3 bucket name for website"
  value       = aws_s3_bucket.website.bucket
}

output "ecr_repository_url" {
  description = "ECR repository URL for Lambda image"
  value       = aws_ecr_repository.lambda.repository_url
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.main.name
}
