# Deployment Guide

## Prerequisites

Before deploying iNFINITE AI 2025, ensure you have:

- Docker 20.10 or later
- Kubernetes 1.24 or later
- kubectl CLI configured
- AWS CLI 2.x configured with appropriate credentials
- Terraform 1.5+ (for infrastructure deployment)
- An AWS account with the following permissions:
  - EKS cluster creation
  - VPC and networking resources
  - S3 bucket creation
  - IAM role/policy creation
  - CloudWatch access

## Deployment Options

### Option 1: Local Development (Docker Compose)

This is the quickest way to get started for development and testing.

```bash
# Clone the repository
git clone https://github.com/NaTo1000/iNFINITE-Ai-2025-Kodex-Docker-K8s-AWS-pack.zip.git
cd iNFINITE-Ai-2025-Kodex-Docker-K8s-AWS-pack.zip

# Create necessary directories
mkdir -p models data logs config

# Build and start services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f infinite-ai
```

Access the application at:
- Application: http://localhost:8080
- Metrics: http://localhost:9090

### Option 2: Kubernetes Deployment (Existing Cluster)

If you already have a Kubernetes cluster:

```bash
# Update kubeconfig (for EKS)
aws eks update-kubeconfig --name infinite-ai-cluster --region us-east-1

# Deploy using kubectl
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml  # Update secrets first!
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/network-policy.yaml

# Or use the deployment script
./scripts/deploy.sh production kubernetes
```

### Option 3: Full AWS Deployment (Terraform)

Deploy complete infrastructure including EKS cluster:

```bash
# Navigate to Terraform directory
cd aws/terraform

# Initialize Terraform
terraform init

# Review the planned changes
terraform plan

# Deploy infrastructure
terraform apply

# Note the outputs
terraform output

# Deploy application to the new cluster
cd ../..
./scripts/deploy.sh production kubernetes
```

### Option 4: Full AWS Deployment (CloudFormation)

Alternative to Terraform using AWS CloudFormation:

```bash
# Deploy infrastructure
aws cloudformation create-stack \
  --stack-name infinite-ai-stack \
  --template-body file://aws/cloudformation/infrastructure.yaml \
  --parameters file://aws/cloudformation/parameters.json \
  --capabilities CAPABILITY_IAM \
  --region us-east-1

# Monitor stack creation
aws cloudformation wait stack-create-complete \
  --stack-name infinite-ai-stack \
  --region us-east-1

# Get stack outputs
aws cloudformation describe-stacks \
  --stack-name infinite-ai-stack \
  --region us-east-1

# Deploy application
./scripts/deploy.sh production kubernetes
```

## Configuration

### 1. Secrets Configuration

Before deploying, update the secrets in `k8s/secret.yaml`:

```yaml
stringData:
  AWS_ACCESS_KEY_ID: "your-access-key"
  AWS_SECRET_ACCESS_KEY: "your-secret-key"
  S3_BUCKET: "your-bucket-name"
  API_KEY: "your-api-key"
```

**Production Recommendation:** Use AWS Secrets Manager or External Secrets Operator instead of hardcoding secrets.

### 2. Environment Variables

Edit `k8s/configmap.yaml` to adjust application settings:

```yaml
data:
  AI_MODEL_PATH: "/models"
  LOG_LEVEL: "INFO"  # DEBUG, INFO, WARNING, ERROR
  AWS_REGION: "us-east-1"
  MAX_WORKERS: "4"
```

### 3. Resource Limits

Adjust resource requests/limits in `k8s/deployment.yaml`:

```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

### 4. Scaling Configuration

Modify HPA settings in `k8s/hpa.yaml`:

```yaml
spec:
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## Post-Deployment Steps

### 1. Verify Deployment

```bash
# Run health check
./scripts/health-check.sh kubernetes

# Check pods
kubectl get pods -n infinite-ai

# Check services
kubectl get svc -n infinite-ai

# Check ingress
kubectl get ingress -n infinite-ai
```

### 2. Access the Application

Get the service endpoint:

```bash
# For LoadBalancer service
kubectl get service infinite-ai-service -n infinite-ai

# For Ingress
kubectl get ingress infinite-ai-ingress -n infinite-ai
```

### 3. Configure DNS (Optional)

If using Ingress, configure your DNS to point to the ALB:

1. Get the ALB DNS name from the Ingress
2. Create a CNAME record pointing to the ALB
3. Update the Ingress with your domain name

### 4. Upload AI Models

Upload your AI models to S3:

```bash
aws s3 cp /path/to/models/ s3://your-models-bucket/ --recursive
```

Or mount models in Kubernetes using PVC (see `k8s/deployment.yaml`).

### 5. Enable Monitoring

Access metrics:
- Prometheus: http://metrics.your-domain.com
- CloudWatch: AWS Console → CloudWatch → Log Groups

## Updating the Deployment

### Update Docker Image

```bash
# Build new image
docker build -t infinite-ai:v2 .

# Tag for registry
docker tag infinite-ai:v2 your-registry/infinite-ai:v2

# Push to registry
docker push your-registry/infinite-ai:v2

# Update deployment
kubectl set image deployment/infinite-ai-deployment \
  infinite-ai=your-registry/infinite-ai:v2 \
  -n infinite-ai

# Or update the deployment.yaml and apply
kubectl apply -f k8s/deployment.yaml
```

### Update Configuration

```bash
# Edit ConfigMap
kubectl edit configmap infinite-ai-config -n infinite-ai

# Or update the file and apply
kubectl apply -f k8s/configmap.yaml

# Restart pods to pick up changes
kubectl rollout restart deployment/infinite-ai-deployment -n infinite-ai
```

## Rollback

If something goes wrong:

```bash
# Check rollout history
kubectl rollout history deployment/infinite-ai-deployment -n infinite-ai

# Rollback to previous version
kubectl rollout undo deployment/infinite-ai-deployment -n infinite-ai

# Rollback to specific revision
kubectl rollout undo deployment/infinite-ai-deployment \
  --to-revision=2 -n infinite-ai
```

## Cleanup

To remove all resources:

```bash
# Cleanup Kubernetes resources
./scripts/cleanup.sh kubernetes

# Cleanup AWS infrastructure (Terraform)
./scripts/cleanup.sh aws

# Cleanup Docker resources
./scripts/cleanup.sh docker

# Cleanup everything
./scripts/cleanup.sh all
```

## Next Steps

- Configure monitoring alerts
- Set up CI/CD pipelines
- Enable backup and disaster recovery
- Configure network policies
- Review security best practices

For more information, see:
- [Troubleshooting Guide](troubleshooting.md)
- [Best Practices](best-practices.md)
