# Stockfolio - Terraform Infrastructure

Production-ready Terraform infrastructure for AWS EKS cluster deploying the Stockfolio microservices application.

## Architecture

- **Region**: ap-south-1 (Mumbai)
- **VPC**: 10.0.0.0/16 with public/private subnets across 2 AZs
- **EKS**: Kubernetes 1.29 with managed node groups
- **Storage**: EBS gp3 for MySQL PersistentVolume

## Repository Structure

```
stockfolio-terraform-infra/
├── terraform/
│   ├── backend.tf              # S3 remote backend config
│   ├── providers.tf             # AWS, Kubernetes, Helm providers
│   ├── modules/
│   │   ├── vpc/               # VPC module
│   │   └── eks/               # EKS cluster module
│   └── environments/
│       ├── dev/               # Dev environment
│       └── prod/              # Prod environment
├── kubernetes/
│   ├── namespace.yaml         # Namespaces
│   ├── deployments/           # Microservices deployments
│   └── ingress/               # ALB ingress
└── .github/workflows/         # CI/CD pipelines
```

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform >= 1.5** installed
3. **AWS CLI** configured
4. **GitHub** repository with secrets configured

## Required GitHub Secrets

Configure these secrets in your GitHub repository:

| Secret | Description | Example |
|--------|-------------|---------|
| `AWS_ROLE_ARN` | IAM Role ARN for GitHub Actions | `arn:aws:iam::123456789:role/github-actions-role` |
| `TF_STATE_BUCKET` | S3 bucket for Terraform state | `stockfolio-terraform-state` |
| `TF_DYNAMODB_TABLE` | DynamoDB table for state locking | `stockfolio-terraform-locks` |

## Quick Start

### Option 1: GitHub Actions (Recommended)

1. Push code to GitHub
2. Go to **Actions** → **Deploy Stockfolio**
3. Select action: `deploy`
4. Select environment: `dev`
5. Click **Run workflow**

### Option 2: Local Deployment

```bash
# Navigate to dev environment
cd terraform/environments/dev

# Initialize Terraform
terraform init -backend-config="bucket=YOUR_BUCKET" -backend-config="key=dev/terraform.tfstate" -backend-config="region=ap-south-1" -backend-config="dynamodb_table=YOUR_TABLE"

# Plan changes
terraform plan

# Apply changes
terraform apply
```

## Services

| Service | Port | Image |
|---------|------|-------|
| frontend | 80 | navlipi/stockfolio-frontend:latest |
| backend | 8080 | navlipi/stockfolio-backend:latest |
| wallet | 8091 | navlipi/stockfolio-wallet:latest |
| about | 8090 | navlipi/stockfolio-about:latest |
| market-data | 7666 | navlipi/stockfolio-market-data:latest |
| mysql | 3306 | mysql:8.0 |

## Database Configuration

- **Database**: stockdb
- **Username**: root
- **Password**: root (change in production!)

## Accessing Services

After deployment:
- Get Load Balancer IP: `kubectl get svc -n stockfolio`
- Access via: `http://<LB-IP>` or configure DuckDNS

## Destroy Resources

To destroy all resources:

1. Go to **Actions** → **Deploy Stockfolio**
2. Select action: `destroy`
3. Select environment: `dev`
4. Click **Run workflow**

## Features

✅ VPC with public/private subnets  
✅ EKS Cluster with managed node groups  
✅ AWS Load Balancer Controller  
✅ Horizontal Pod Autoscaler  
✅ Prometheus & Grafana monitoring  
✅ EBS CSI Driver for persistent storage  
✅ IRSA for secure IAM roles  
✅ Remote state with S3 + DynamoDB locking  

## Notes

- MySQL password is set to `root` - change in production!
- Grafana password is set to `admin123` - change in production!
- Ensure your IAM role has permissions for EKS, EC2, VPC, S3, DynamoDB

## License

MIT
