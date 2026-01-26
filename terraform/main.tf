terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Local values for naming consistency
locals {
  project_name = var.project_name
  environment  = var.environment
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}

# S3 Bucket for Static Website Hosting
resource "aws_s3_bucket" "website" {
  bucket = "${local.project_name}-${local.environment}-website-${random_string.suffix.result}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.website]
}

# DynamoDB Table
resource "aws_dynamodb_table" "main" {
  name         = "${local.project_name}-${local.environment}-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  global_secondary_index {
    name            = "CreatedAtIndex"
    hash_key        = "created_at"
    projection_type = "ALL"
  }

  tags = local.common_tags
}

# ECR Repository for Lambda Docker Image
resource "aws_ecr_repository" "lambda" {
  name                 = "${local.project_name}-${local.environment}-lambda"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda" {
  name = "${local.project_name}-${local.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "lambda" {
  name = "${local.project_name}-${local.environment}-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.main.arn
      }
    ]
  })
}

# Lambda Function (Container Image)
resource "aws_lambda_function" "api" {
  function_name = "${local.project_name}-${local.environment}-api"
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.lambda.repository_url}:latest"
  timeout       = 30
  memory_size   = 512

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.main.name
      REGION     = var.aws_region
    }
  }

  depends_on = [aws_iam_role_policy.lambda]

  tags = local.common_tags
}

resource "aws_lambda_function_url" "api" {
  function_name      = aws_lambda_function.api.function_name
  authorization_type = "NONE"
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "main" {
  name = "${local.project_name}-${local.environment}-api"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.common_tags
}

# API Gateway Resource and Methods
resource "aws_api_gateway_resource" "items" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "items"
}

resource "aws_api_gateway_method" "get_items" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.items.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "post_item" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.items.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_get" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.items.id
  http_method = aws_api_gateway_method.get_items.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

resource "aws_api_gateway_integration" "lambda_post" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.items.id
  http_method = aws_api_gateway_method.post_item.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "main" {
  depends_on = [
    aws_api_gateway_integration.lambda_get,
    aws_api_gateway_integration.lambda_post,
    aws_api_gateway_method.get_items,
    aws_api_gateway_method.post_item
  ]

  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = local.environment

  lifecycle {
    create_before_destroy = true
  }
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# CloudFront Distribution
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for ${local.project_name} website"
}

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${local.project_name} ${local.environment} distribution"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.website.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  origin {
    domain_name = "${aws_api_gateway_rest_api.main.id}.execute-api.${var.aws_region}.amazonaws.com"
    origin_id   = "API-Gateway"
    
    origin_path = "/${local.environment}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "API-Gateway"

    forwarded_values {
      query_string = true
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = local.common_tags

  depends_on = [aws_api_gateway_deployment.main]
}

# Random suffix for unique bucket names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Update S3 bucket policy for CloudFront OAI
resource "aws_s3_bucket_policy" "cloudfront" {
  bucket = aws_s3_bucket.website.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudFrontAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${aws_cloudfront_origin_access_identity.oai.id}"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })
  depends_on = [aws_cloudfront_origin_access_identity.oai]
}
