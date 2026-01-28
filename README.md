# AWS Serverless Web Application

[![AWS](https://img.shields.io/badge/AWS-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Python](https://img.shields.io/badge/Python-FFD43B?style=for-the-badge&logo=python&logoColor=blue)](https://www.python.org/)

A complete serverless web application built with AWS services (S3, API Gateway, Lambda, DynamoDB, CloudFront) using Terraform for Infrastructure as Code and Docker for containerized Lambda functions.

## 🏗️ Architecture

![image](https://github.com/abhijitray7810/aws-serverless-webapp-terraform/blob/c567db466457383f2725c1ceda2bf7601f77d2e5/assets/Screenshot%202026-01-28%20123911.png)

## 📋 Prerequisites
![Image](https://github.com/abhijitray7810/aws-serverless-webapp-terraform/blob/9e5de63e4d1fba899b15402063a94bf71d7c15b1/assets/Screenshot%202026-01-26%20173724.png)
### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | v2.x | AWS resource management |
| [Terraform](https://www.terraform.io/downloads.html) | >= 1.0 | Infrastructure as Code |
| [Docker](https://docs.docker.com/get-docker/) | >= 20.10 | Containerization |
| [Git](https://git-scm.com/downloads) | >= 2.30 | Version control |

### AWS Requirements

- AWS Account with programmatic access
- IAM User/Role with permissions:
  - `AmazonS3FullAccess`
  - `AmazonDynamoDBFullAccess`
  - `AWSLambda_FullAccess`
  - `AmazonAPIGatewayAdministrator`
  - `CloudFrontFullAccess`
  - `AmazonEC2ContainerRegistryFullAccess`
  - `IAMFullAccess`

### Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_DEFAULT_REGION=us-east-1
```

## 🚀 Quick Start
![Image](https://github.com/abhijitray7810/aws-serverless-webapp-terraform/blob/9e5de63e4d1fba899b15402063a94bf71d7c15b1/assets/Screenshot%202026-01-26%20172601.png)
### 1. Clone Repository

```bash
git clone https://github.com/yourusername/aws-serverless-webapp.git
cd aws-serverless-webapp
```

### 2. Set Environment Variables

```bash
export AWS_REGION=us-east-1
export PROJECT_NAME=serverless-app
export ENVIRONMENT=dev
```

### 3. Deploy Everything

```bash
chmod +x deploy.sh
./deploy.sh
```

## 📁 Project Structure

``` 
aws-serverless-webapp/
├── 📁 terraform/                 # Infrastructure as Code
│   ├── 📄 main.tf               # Main Terraform configuration
│   ├── 📄 variables.tf          # Input variables
│   ├── 📄 outputs.tf            # Output values
│   ├── 📄 backend.tf            # Remote state configuration (optional)
│   └── 📁 modules/              # Reusable modules (optional)
│
├── 📁 src/
│   ├── 📁 lambda/               # Lambda function code
│   │   ├── 📄 Dockerfile        # Container definition
│   │   ├── 📄 requirements.txt  # Python dependencies
│   │   └── 📄 app.py           # Lambda handler
│   │
│   └── 📁 frontend/             # Static website files
│       └── 📄 index.html        # Single-page application
│
├── 📄 docker-compose.yml        # Local development
├── 📄 deploy.sh                # Automated deployment script
└── 📄 README.md                # This file
```

## 🔧 Manual Deployment Steps
![Image](https://github.com/abhijitray7810/aws-serverless-webapp-terraform/blob/9e5de63e4d1fba899b15402063a94bf71d7c15b1/assets/Screenshot%202026-01-26%20172715.png)
### Step 1: Initialize Terraform

```bash
cd terraform

# Initialize Terraform (downloads providers)
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan
```

### Step 2: Create ECR Repository

```bash
# Apply only ECR resource first
terraform apply -target=aws_ecr_repository.lambda -auto-approve

# Get ECR repository URL
export ECR_URL=$(terraform output -raw ecr_repository_url)
echo "ECR Repository: $ECR_URL"
```

### Step 3: Build and Push Docker Image

```bash
cd ../src/lambda

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $(echo $ECR_URL | cut -d'/' -f1)

# Build Docker image
docker build -t $PROJECT_NAME-lambda .

# Tag image
docker tag $PROJECT_NAME-lambda:latest $ECR_URL:latest

# Push to ECR
docker push $ECR_URL:latest

# Verify push
aws ecr describe-images --repository-name $PROJECT_NAME-$ENVIRONMENT-lambda
```

### Step 4: Deploy Infrastructure

```bash
cd ../../terraform

# Apply all resources
terraform apply -auto-approve

# Get outputs
terraform output
```

### Step 5: Deploy Frontend

```bash
# Get S3 bucket name
export S3_BUCKET=$(terraform output -raw s3_website_bucket)

# Sync frontend files to S3
aws s3 sync ../src/frontend s3://$S3_BUCKET --delete

# Verify upload
aws s3 ls s3://$S3_BUCKET --recursive
```

### Step 6: Invalidate CloudFront Cache

```bash
# Get CloudFront Distribution ID
export DISTRIBUTION_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Comment=='$PROJECT_NAME $ENVIRONMENT distribution'].Id" \
  --output text)

# Create invalidation
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/*" \
  --query 'Invalidation.Id'

# Wait for invalidation to complete (optional)
aws cloudfront wait invalidation-completed \
  --distribution-id $DISTRIBUTION_ID \
  --id YOUR_INVALIDATION_ID
```

## 🧪 Local Development
![Image](https://github.com/abhijitray7810/aws-serverless-webapp-terraform/blob/9e5de63e4d1fba899b15402063a94bf71d7c15b1/assets/Screenshot%202026-01-26%20172917.png)
### Test Lambda Locally

```bash
# Start local DynamoDB
docker-compose up -d dynamodb-local

# Start Lambda locally
docker-compose up lambda-local

# Test in another terminal
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \
  -d '{"httpMethod": "GET", "path": "/items"}'
```

### Test with LocalStack (Optional)

```bash
# Install LocalStack
pip install localstack

# Start LocalStack
localstack start

# Deploy to local environment
terraform workspace new local
terraform apply -var="environment=local"
```

## 📊 Monitoring & Debugging
![Image](https://github.com/abhijitray7810/aws-serverless-webapp-terraform/blob/9e5de63e4d1fba899b15402063a94bf71d7c15b1/assets/Screenshot%202026-01-26%20172952.png)
### View CloudWatch Logs

```bash
# Lambda logs
aws logs tail /aws/lambda/$PROJECT_NAME-$ENVIRONMENT-api --follow

# API Gateway logs (if enabled)
aws logs tail "API-Gateway-Execution-Logs_$(terraform output -raw api_gateway_id)/$ENVIRONMENT" --follow
```

### Test API Endpoints

```bash
# Get API endpoint
export API_URL=$(terraform output -raw api_gateway_endpoint)

# Test GET
curl -v $API_URL

# Test POST
curl -v -X POST $API_URL \
  -H "Content-Type: application/json" \
  -d '{"data": "Hello from curl"}'

# Test through CloudFront
export CF_URL=$(terraform output -raw cloudfront_domain_name)
curl -v https://$CF_URL/api/items
```

### Common Issues
![Image](https://github.com/abhijitray7810/aws-serverless-webapp-terraform/blob/9e5de63e4d1fba899b15402063a94bf71d7c15b1/assets/Screenshot%202026-01-26%20173104.png)
#### 1. CloudFront 403/404 Errors

**Cause:** CloudFront not routing `/api/*` to API Gateway  
**Fix:** Check CloudFront origin path includes stage name (`/dev`, `/prod`)

```bash
# Verify CloudFront origins
aws cloudfront get-distribution-config --id $DISTRIBUTION_ID
```

#### 2. Lambda 502 Bad Gateway

**Cause:** Lambda response format incorrect  
**Fix:** Ensure response includes `statusCode`, `headers`, and `body`

```python
# Correct response format
return {
    'statusCode': 200,
    'headers': {'Content-Type': 'application/json'},
    'body': json.dumps({'message': 'Success'})
}
```

#### 3. CORS Errors

**Cause:** Missing CORS headers  
**Fix:** Update Lambda to return CORS headers:

```python
headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'OPTIONS,POST,GET'
}
```

#### 4. DynamoDB Access Denied

**Cause:** IAM role missing permissions  
**Fix:** Verify Lambda execution role has DynamoDB permissions:

```bash
aws iam get-role-policy \
  --role-name $PROJECT_NAME-$ENVIRONMENT-lambda-role \
  --policy-name $PROJECT_NAME-$ENVIRONMENT-lambda-policy
```

## 🔐 Security Best Practices
![Image](https://github.com/abhijitray7810/aws-serverless-webapp-terraform/blob/9e5de63e4d1fba899b15402063a94bf71d7c15b1/assets/Screenshot%202026-01-26%20173133.png)
### 1. Enable Remote State (Production)

```hcl
# terraform/backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "serverless-app/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### 2. Use Secrets Manager

```python
# Instead of hardcoding
import boto3
secrets = boto3.client('secretsmanager')
response = secrets.get_secret_value(SecretId='my-secret')
```

### 3. Enable WAF on CloudFront

```hcl
resource "aws_wafv2_web_acl" "main" {
  name  = "${local.project_name}-waf"
  scope = "CLOUDFRONT"
  
  # Add rules for SQL injection, XSS protection
}
```

### 4. Enable API Gateway Authorization

```hcl
resource "aws_api_gateway_authorizer" "cognito" {
  name          = "cognito"
  rest_api_id   = aws_api_gateway_rest_api.main.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [aws_cognito_user_pool.main.arn]
}
```

## 💰 Cost Optimization

| Service | Free Tier | Estimated Monthly Cost |
|---------|-----------|------------------------|
| S3 | 5GB storage | ~$0.50 |
| Lambda | 1M requests | ~$0.20 (1M requests) |
| API Gateway | 1M calls | ~$3.50 (1M calls) |
| DynamoDB | 25GB storage | ~$1.25 (on-demand) |
| CloudFront | 50GB transfer | ~$4.50 (100GB) |
| **Total** | | **~$10/month** |

### Cost-Saving Tips

1. **Use DynamoDB On-Demand** for unpredictable traffic
2. **Enable CloudFront caching** to reduce origin requests
3. **Set Lambda memory** appropriately (128MB-512MB)
4. **Use S3 Intelligent-Tiering** for infrequently accessed data

## 🧹 Cleanup
![Image](https://github.com/abhijitray7810/aws-serverless-webapp-terraform/blob/9e5de63e4d1fba899b15402063a94bf71d7c15b1/assets/Screenshot%202026-01-26%20173222.png)
### Destroy Infrastructure

```bash
cd terraform

# Empty S3 bucket first
aws s3 rm s3://$(terraform output -raw s3_website_bucket) --recursive

# Destroy all resources
terraform destroy -auto-approve

# Clean up ECR images
aws ecr batch-delete-image \
  --repository-name $PROJECT_NAME-$ENVIRONMENT-lambda \
  --image-ids imageTag=latest
```
![Image](https://github.com/abhijitray7810/aws-serverless-webapp-terraform/blob/9e5de63e4d1fba899b15402063a94bf71d7c15b1/assets/Screenshot%202026-01-26%20173206.png)
### Remove Local Files

```bash
# Remove Terraform state and cache
rm -rf terraform/.terraform terraform/terraform.tfstate*

# Remove Docker images
docker rmi $(docker images -q $PROJECT_NAME-lambda) --force
```
![Image](https://github.com/abhijitray7810/aws-serverless-webapp-terraform/blob/9e5de63e4d1fba899b15402063a94bf71d7c15b1/assets/Screenshot%202026-01-26%20173509.png)
## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📚 Additional Resources

- [AWS Serverless Application Model (SAM)](https://docs.aws.amazon.com/serverless-application-model/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Lambda Container Images](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html)
- [CloudFront Best Practices](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/best-practices.html)

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file.

## 🙏 Acknowledgments

- AWS Documentation
- Terraform Community
- Docker Community

---

**Happy Serverless Coding! 🚀**

For issues and questions, please open a GitHub issue.
```

This README includes:

1. **Visual architecture diagram**
2. **Prerequisites with installation links**
3. **Quick start (one-command deployment)**
4. **Detailed manual steps**
5. **Local development instructions**
6. **Comprehensive troubleshooting section**
7. **Security best practices**
8. **Cost estimates and optimization tips**
9. **Cleanup instructions**
10. **Contributing guidelines**
