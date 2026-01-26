# AWS Serverless WebApp with Terraform

This repository contains a fully **serverless web application** built on **AWS** using **Lambda, API Gateway, DynamoDB, S3, and CloudFront**, provisioned and managed through **Terraform**. The app demonstrates a simple CRUD interface for managing items with a static frontend hosted on S3 and a backend powered by Lambda.

---

## Features

- **Serverless architecture**: No servers to manage.
- **Frontend**: Static website hosted on S3 with CloudFront CDN.
- **Backend**: AWS Lambda using Docker container image.
- **API**: REST API using API Gateway integrated with Lambda.
- **Database**: DynamoDB table for storing items.
- **Infrastructure as Code**: Fully provisioned using Terraform.
- **CloudFront caching**: CDN for faster delivery and global access.

---

## Architecture

```

User -> CloudFront -> S3 (Frontend)
-> API Gateway -> Lambda -> DynamoDB

````

- **S3**: Hosts static frontend (`index.html`).  
- **CloudFront**: Provides HTTPS, caching, and global distribution.  
- **API Gateway**: Exposes `/items` endpoint.  
- **Lambda**: Handles API logic.  
- **DynamoDB**: Stores data in a fully managed NoSQL table.  
- **Terraform**: Manages all AWS resources and infrastructure.

---

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0  
- [AWS CLI](https://aws.amazon.com/cli/) configured with proper IAM credentials  
- Docker (for building Lambda container image)  
- Node.js / Python or any frontend tooling if you plan to extend the frontend

---

## Getting Started

1. **Clone the repository:**

```bash
git clone https://github.com/your-username/aws-serverless-webapp-terraform.git
cd aws-serverless-webapp-terraform
````

2. **Navigate to Terraform directory:**

```bash
cd terraform
```

3. **Initialize Terraform:**

```bash
terraform init
```

4. **Plan Terraform deployment:**

```bash
terraform plan
```

5. **Apply Terraform deployment:**

```bash
terraform apply
```

* Confirm with `yes` when prompted.
* Terraform will provision all AWS resources.

---

## Deploy Frontend

1. Navigate to the frontend directory:

```bash
cd ../src/frontend
```

2. Sync files to S3 bucket created by Terraform:

```bash
aws s3 sync ./ s3://<your-s3-bucket-name>/
```

* Replace `<your-s3-bucket-name>` with the output from Terraform.

3. Invalidate CloudFront cache to propagate changes:

```bash
aws cloudfront create-invalidation --distribution-id <your-cloudfront-id> --paths "/*"
```

---

## API Usage

* **Get all items**:

```bash
curl https://<cloudfront-domain>/api/items
```

* **Add a new item**:

```bash
curl -X POST https://<cloudfront-domain>/api/items \
-H "Content-Type: application/json" \
-d '{"id":"1","name":"Sample Item","created_at":"2026-01-26"}'
```

---

## Terraform Outputs

After deployment, Terraform will output:

* `api_gateway_endpoint` – API Gateway URL
* `cloudfront_domain_name` – CloudFront domain for frontend & API
* `dynamodb_table_name` – DynamoDB table name
* `ecr_repository_url` – ECR repository URL for Lambda container
* `s3_website_bucket` – S3 bucket hosting frontend

---

## Folder Structure

```
aws-serverless-webapp-terraform/
├── terraform/          # Terraform code for infrastructure
├── src/
│   ├── frontend/       # Static frontend files
│   └── lambda/         # Lambda function code (Python + Dockerfile)
└── docker-compose.yml  # Optional Docker setup
```

---

## Clean Up

To delete all resources and avoid AWS charges:

```bash
cd terraform
terraform destroy
```

---

## Notes

* The API Gateway stage is automatically created using the environment variable in Terraform.
* The CloudFront distribution uses **default certificate** for HTTPS.
* You can extend the Lambda logic to handle more CRUD operations.

---

## License

This project is licensed under the MIT License.

---

## Author

Abhijit Ray

```

---

If you want, I can also make an **enhanced version** with:  

- Badges (Terraform, AWS, build status)  
- Demo screenshot section  
- Automatic CloudFront/API URLs in README  

It will make the repo **GitHub-ready and professional**.  

Do you want me to do that next?
```
