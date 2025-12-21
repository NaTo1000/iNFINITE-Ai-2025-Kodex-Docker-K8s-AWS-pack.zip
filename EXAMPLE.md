# Example: Getting Started with iNFINITE AI 2025

This example demonstrates how to quickly get started with the iNFINITE AI 2025 deployment pack.

## Quick Start - Local Development

### 1. Clone and Setup

```bash
git clone https://github.com/NaTo1000/iNFINITE-Ai-2025-Kodex-Docker-K8s-AWS-pack.zip
cd iNFINITE-Ai-2025-Kodex-Docker-K8s-AWS-pack.zip

# Create necessary directories
mkdir -p models data logs
```

### 2. Run with Docker Compose

```bash
# Start all services
docker-compose up -d

# Check logs
docker-compose logs -f infinite-ai

# Test the application
curl http://localhost:8080/health
curl http://localhost:8080/

# Make a prediction request
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"input": "test data"}'

# Check metrics
curl http://localhost:8080/metrics
```

### 3. Stop Services

```bash
docker-compose down
```

## Example: Deploy to Kubernetes

### 1. Create EKS Cluster (if needed)

```bash
# Using Terraform
cd aws/terraform
terraform init
terraform apply
cd ../..

# Or using CloudFormation
aws cloudformation create-stack \
  --stack-name infinite-ai-stack \
  --template-body file://aws/cloudformation/infrastructure.yaml \
  --parameters file://aws/cloudformation/parameters.json \
  --capabilities CAPABILITY_IAM
```

### 2. Configure kubectl

```bash
aws eks update-kubeconfig --name infinite-ai-cluster --region us-east-1
```

### 3. Deploy Application

```bash
# Deploy using the script
./scripts/deploy.sh production kubernetes

# Or manually
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml  # Update secrets first!
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml
```

### 4. Check Deployment

```bash
# Run health check
./scripts/health-check.sh kubernetes

# Get service endpoint
kubectl get service infinite-ai-service -n infinite-ai

# Get pod logs
kubectl logs -f deployment/infinite-ai-deployment -n infinite-ai
```

## Example: Custom Model Integration

### 1. Add Your Model Files

```bash
# Upload to S3
aws s3 cp /path/to/your/model.bin s3://infinite-ai-models-ACCOUNT_ID/models/

# Or mount locally for Docker
cp /path/to/your/model.bin models/
```

### 2. Update Application Code

Edit `src/main.py` to load and use your model:

```python
import boto3
from transformers import AutoModel, AutoTokenizer

# Load model from S3 or local
def load_model():
    s3 = boto3.client('s3')
    bucket = os.getenv('S3_BUCKET')
    model_key = 'models/your-model.bin'
    
    # Download if using S3
    local_path = f'{AI_MODEL_PATH}/your-model.bin'
    s3.download_file(bucket, model_key, local_path)
    
    # Load model
    model = AutoModel.from_pretrained(local_path)
    tokenizer = AutoTokenizer.from_pretrained(local_path)
    
    return model, tokenizer

# Update prediction endpoint
@app.route('/predict', methods=['POST'])
def predict():
    data = request.get_json()
    
    # Use your model
    inputs = tokenizer(data['text'], return_tensors='pt')
    outputs = model(**inputs)
    
    result = process_outputs(outputs)
    
    return jsonify(result), 200
```

### 3. Rebuild and Deploy

```bash
# Rebuild Docker image
docker build -t your-registry/infinite-ai:v2 .
docker push your-registry/infinite-ai:v2

# Update Kubernetes deployment
kubectl set image deployment/infinite-ai-deployment \
  infinite-ai=your-registry/infinite-ai:v2 \
  -n infinite-ai
```

## Example: Monitoring and Observability

### 1. Access Metrics

```bash
# Port forward Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Access at http://localhost:9090
```

### 2. View Logs in CloudWatch

```bash
# Get logs from CloudWatch
aws logs tail /aws/eks/infinite-ai-cluster/application --follow
```

### 3. Set Up Alerts

Create a Prometheus alert rule:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: infinite-ai-alerts
  namespace: infinite-ai
spec:
  groups:
  - name: infinite-ai
    rules:
    - alert: HighErrorRate
      expr: rate(http_requests_total{status="500"}[5m]) > 0.05
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High error rate in iNFINITE AI"
        description: "Error rate is {{ $value | humanizePercentage }}"
```

## Example: Scaling

### 1. Manual Scaling

```bash
# Scale pods
kubectl scale deployment/infinite-ai-deployment --replicas=5 -n infinite-ai

# Scale nodes (if using node groups)
aws eks update-nodegroup-config \
  --cluster-name infinite-ai-cluster \
  --nodegroup-name infinite-ai-node-group \
  --scaling-config minSize=5,maxSize=15,desiredSize=5
```

### 2. Auto-Scaling

The HPA is already configured. Adjust thresholds in `k8s/hpa.yaml`:

```yaml
spec:
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## Example: CI/CD Integration

### 1. GitHub Actions Example

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to EKS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
      
      - name: Build and push Docker image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/infinite-ai:$IMAGE_TAG .
          docker push $ECR_REGISTRY/infinite-ai:$IMAGE_TAG
      
      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig --name infinite-ai-cluster --region us-east-1
      
      - name: Deploy to Kubernetes
        run: |
          kubectl set image deployment/infinite-ai-deployment \
            infinite-ai=$ECR_REGISTRY/infinite-ai:$IMAGE_TAG \
            -n infinite-ai
```

## Example: Disaster Recovery

### 1. Backup

```bash
# Backup Kubernetes resources
velero backup create infinite-ai-backup-$(date +%Y%m%d) \
  --include-namespaces infinite-ai

# Backup S3 data
aws s3 sync s3://infinite-ai-models-ACCOUNT_ID/ \
  s3://infinite-ai-models-backup-ACCOUNT_ID/
```

### 2. Restore

```bash
# Restore from backup
velero restore create --from-backup infinite-ai-backup-20240101

# Verify
kubectl get all -n infinite-ai
```

## Example: Cost Optimization

### 1. Use Spot Instances

Update `aws/terraform/main.tf`:

```hcl
eks_managed_node_groups = {
  main = {
    capacity_type = "SPOT"
    instance_types = ["t3.large", "t3.xlarge", "c5.large"]
  }
}
```

### 2. Schedule Scaling

```bash
# Scale down at night (10 PM)
kubectl create cronjob scale-down \
  --schedule="0 22 * * *" \
  --image=bitnami/kubectl \
  -- kubectl scale deployment/infinite-ai-deployment --replicas=1 -n infinite-ai

# Scale up in morning (6 AM)
kubectl create cronjob scale-up \
  --schedule="0 6 * * *" \
  --image=bitnami/kubectl \
  -- kubectl scale deployment/infinite-ai-deployment --replicas=3 -n infinite-ai
```

## Next Steps

1. Review the [Deployment Guide](../docs/deployment-guide.md)
2. Check [Best Practices](../docs/best-practices.md)
3. Read the [Troubleshooting Guide](../docs/troubleshooting.md)
4. Customize configuration for your use case
5. Set up monitoring and alerting
6. Implement CI/CD pipelines
7. Test disaster recovery procedures
