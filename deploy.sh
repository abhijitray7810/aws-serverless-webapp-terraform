# 1. Update Terraform
cd terraform
terraform apply

# 2. Rebuild and push Docker image if Lambda code changed
cd ../src/lambda
docker build -t lambda-api .
aws ecr get-login-password | docker login --username AWS --password-stdin $(terraform -chdir=../../terraform output -raw ecr_repository_url | cut -d'/' -f1)
docker tag lambda-api:latest $(terraform -chdir=../../terraform output -raw ecr_repository_url):latest
docker push $(terraform -chdir=../../terraform output -raw ecr_repository_url):latest

# 3. Update Lambda function
aws lambda update-function-code \
  --function-name $(terraform -chdir=../../terraform output -raw lambda_function_name) \
  --image-uri $(terraform -chdir=../../terraform output -raw ecr_repository_url):latest

# 4. Sync frontend to S3
aws s3 sync ../frontend s3://$(terraform -chdir=../../terraform output -raw s3_website_bucket) --delete

# 5. Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id $(terraform -chdir=../../terraform output -raw cloudfront_distribution_id) \
  --paths "/*"
