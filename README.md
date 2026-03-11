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
│   ├── providers.tf            # AWS, Kubernetes, Helm providers
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
2. **GitHub repository** with secrets configured

## Required GitHub Secrets

### Step 1: Create IAM Role for GitHub Actions

Create a new IAM Role with OIDC provider for GitHub Actions:

1. Go to IAM → Roles → Create role
2. Select **Web identity**
3. Choose your GitHub OIDC provider (create one if needed)
4. Set repository: `your-username/stockfolio-terraform-infra`
5. Attach the policy below:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*", "eks:*", "iam:*", "s3:*", "dynamodb:*",
        "logs:*", "cloudwatch:*", "autoscaling:*", "ecr:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### Step 2: Add GitHub Secret

Go to **GitHub → Settings → Secrets and variables → Actions** and add only:

| Secret Name | Value |
|------------|-------|
| `AWS_ROLE_ARN` | `arn:aws:iam::YOUR_ACCOUNT_ID:role/GitHubActionsRole` |

**Replace `YOUR_ACCOUNT_ID` with your AWS Account ID!**

The workflow will **automatically create**:
- S3 bucket: `stockfolio-terraform-state`
- DynamoDB table: `stockfolio-terraform-locks`

## Quick Start

### GitHub Actions (Recommended)

1. Push code to GitHub
2. Go to **Actions** → **Deploy Stockfolio**
3. Select action: `deploy`
4. Select environment: `dev`
5. Click **Run workflow**

The workflow will:
1. Create S3 bucket & DynamoDB table automatically
2. Run Terraform init/plan/apply
3. Deploy Kubernetes resources
4. Output Load Balancer hostname

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
- **Password**: root

## Accessing Services

After deployment:
- Get Load Balancer: `kubectl get svc -n stockfolio`
- Configure DuckDNS with the ALB hostname
- Access at: `http://stockfolio.duckdns.org`

## Destroy Resources

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

## License

MIT
