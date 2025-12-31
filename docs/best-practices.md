# Best Practices

This document outlines best practices for deploying and managing iNFINITE AI 2025 in production.

## Table of Contents

1. [Security Best Practices](#security-best-practices)
2. [Operational Best Practices](#operational-best-practices)
3. [Performance Best Practices](#performance-best-practices)
4. [Cost Optimization](#cost-optimization)
5. [Monitoring and Observability](#monitoring-and-observability)

## Security Best Practices

### 1. Secrets Management

**Never commit secrets to version control:**

❌ **DON'T:**
```yaml
stringData:
  AWS_SECRET_ACCESS_KEY: "AKIAIOSFODNN7EXAMPLE"
```

✅ **DO:**
Use AWS Secrets Manager with External Secrets Operator:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: infinite-ai-external-secret
spec:
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: infinite-ai-secret
  data:
  - secretKey: AWS_SECRET_ACCESS_KEY
    remoteRef:
      key: infinite-ai/credentials
      property: secret_key
```

Or use AWS IAM Roles for Service Accounts (IRSA):

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: infinite-ai-sa
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/infinite-ai-role
```

### 2. Network Security

**Implement Network Policies:**

```yaml
# Deny all ingress by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

**Use Private Subnets:**
- Place worker nodes in private subnets
- Use NAT Gateway for outbound traffic
- Restrict security group rules

**Enable VPC Flow Logs:**
```bash
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids vpc-xxxxx \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name /aws/vpc/flowlogs
```

### 3. Container Security

**Scan images for vulnerabilities:**

```bash
# Using AWS ECR
aws ecr start-image-scan --repository-name infinite-ai --image-id imageTag=latest

# Using Trivy
trivy image infinite-ai:latest
```

**Run as non-root user:**

```dockerfile
# In Dockerfile
RUN useradd -m -u 1000 appuser
USER appuser
```

**Use read-only root filesystem:**

```yaml
securityContext:
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000
```

### 4. RBAC Configuration

**Principle of least privilege:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: infinite-ai-role
  namespace: infinite-ai
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
```

### 5. Enable Encryption

**Encrypt EKS secrets:**
```yaml
# In Terraform
cluster_encryption_config = {
  provider_key_arn = aws_kms_key.eks.arn
  resources        = ["secrets"]
}
```

**Encrypt data at rest:**
- Enable S3 bucket encryption
- Use encrypted EBS volumes
- Enable RDS encryption (if using database)

### 6. Audit Logging

**Enable EKS audit logs:**

```yaml
cluster_enabled_log_types = [
  "api",
  "audit",
  "authenticator"
]
```

**Enable AWS CloudTrail:**
```bash
aws cloudtrail create-trail \
  --name infinite-ai-trail \
  --s3-bucket-name my-cloudtrail-bucket \
  --is-multi-region-trail
```

## Operational Best Practices

### 1. Use Infrastructure as Code

**Always use IaC:**
- Terraform for infrastructure
- Kubernetes manifests for applications
- Version control everything
- Use CI/CD pipelines

### 2. Multi-Environment Strategy

**Separate environments:**

```
├── environments/
│   ├── dev/
│   │   └── values.yaml
│   ├── staging/
│   │   └── values.yaml
│   └── production/
│       └── values.yaml
```

**Use namespaces per environment:**
```bash
kubectl create namespace infinite-ai-dev
kubectl create namespace infinite-ai-staging
kubectl create namespace infinite-ai-prod
```

### 3. Automated Deployments

**Use GitOps with ArgoCD or Flux:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infinite-ai
spec:
  source:
    repoURL: https://github.com/yourorg/infinite-ai
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: infinite-ai
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 4. Backup Strategy

**Backup critical data:**

```bash
# Velero for Kubernetes resources
velero backup create infinite-ai-backup \
  --include-namespaces infinite-ai

# S3 versioning for models
aws s3api put-bucket-versioning \
  --bucket infinite-ai-models \
  --versioning-configuration Status=Enabled
```

### 5. Disaster Recovery

**Document recovery procedures:**
- RTO (Recovery Time Objective): < 1 hour
- RPO (Recovery Point Objective): < 15 minutes

**Test disaster recovery:**
```bash
# Simulate failure
kubectl delete namespace infinite-ai

# Restore from backup
velero restore create --from-backup infinite-ai-backup
```

### 6. Blue-Green Deployments

**Use deployment strategies:**

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 50%
      maxUnavailable: 0
```

**Or use Canary deployments with Flagger:**
```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: infinite-ai
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: infinite-ai-deployment
  analysis:
    interval: 1m
    threshold: 5
    maxWeight: 50
    stepWeight: 10
```

## Performance Best Practices

### 1. Resource Management

**Set appropriate resource requests and limits:**

```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

**Use Vertical Pod Autoscaler for recommendations:**

```bash
kubectl describe vpa infinite-ai-vpa -n infinite-ai
```

### 2. Horizontal Pod Autoscaling

**Configure HPA with multiple metrics:**

```yaml
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      type: Utilization
      averageUtilization: 70
- type: Resource
  resource:
    name: memory
    target:
      type: Utilization
      averageUtilization: 80
- type: Pods
  pods:
    metric:
      name: requests_per_second
    target:
      type: AverageValue
      averageValue: "1000"
```

### 3. Cluster Autoscaling

**Enable cluster autoscaler:**

```yaml
# Node group tags
tags = {
  "k8s.io/cluster-autoscaler/enabled" = "true"
  "k8s.io/cluster-autoscaler/${cluster_name}" = "owned"
}
```

### 4. Optimize Container Images

**Multi-stage builds:**

```dockerfile
FROM python:3.11 as builder
# Build dependencies

FROM python:3.11-slim
# Copy only what's needed
COPY --from=builder /root/.local /root/.local
```

**Use appropriate base images:**
- Use `-slim` or `-alpine` variants
- Remove unnecessary packages
- Combine RUN commands

### 5. Caching Strategy

**Implement Redis caching:**

```python
import redis

cache = redis.Redis(host='redis', port=6379)

def get_prediction(input_data):
    cache_key = f"prediction:{hash(input_data)}"
    cached = cache.get(cache_key)
    if cached:
        return cached
    
    result = model.predict(input_data)
    cache.setex(cache_key, 3600, result)
    return result
```

### 6. Database Optimization

**Use connection pooling:**
- Configure appropriate pool sizes
- Use read replicas
- Implement query caching

## Cost Optimization

### 1. Right-Sizing

**Use appropriate instance types:**
- Start with `t3.medium` for development
- Use `t3.large` or `c5.large` for production
- Use Spot instances for non-critical workloads

**Monitor and adjust:**
```bash
# Check actual resource usage
kubectl top nodes
kubectl top pods -n infinite-ai
```

### 2. Spot Instances

**Use Spot instances for cost savings:**

```yaml
# In Terraform
capacity_type = "SPOT"
instance_types = ["t3.large", "t3.xlarge", "c5.large"]
```

### 3. Auto-Scaling

**Scale down during off-hours:**

```yaml
# CronJob to scale down
apiVersion: batch/v1
kind: CronJob
metadata:
  name: scale-down
spec:
  schedule: "0 22 * * *"  # 10 PM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: kubectl
            image: bitnami/kubectl
            command:
            - kubectl
            - scale
            - deployment/infinite-ai-deployment
            - --replicas=1
```

### 4. S3 Lifecycle Policies

**Move old data to cheaper storage:**

```json
{
  "Rules": [{
    "Id": "MoveToGlacier",
    "Status": "Enabled",
    "Transitions": [{
      "Days": 90,
      "StorageClass": "GLACIER"
    }]
  }]
}
```

### 5. Reserved Capacity

**Use Savings Plans or Reserved Instances:**
- For predictable workloads
- 1-year or 3-year commitments
- Up to 72% savings

## Monitoring and Observability

### 1. Metrics Collection

**Use Prometheus for metrics:**

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9090"
  prometheus.io/path: "/metrics"
```

### 2. Logging

**Structured logging:**

```python
import logging
import json

logger = logging.getLogger(__name__)

logger.info(json.dumps({
    "event": "prediction_complete",
    "duration_ms": 123,
    "model_version": "v1.2.3"
}))
```

### 3. Distributed Tracing

**Use AWS X-Ray or Jaeger:**

```python
from aws_xray_sdk.core import xray_recorder

@xray_recorder.capture('predict')
def predict(input_data):
    # Your code
    pass
```

### 4. Alerting

**Set up alerts for critical metrics:**

```yaml
# PrometheusRule
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: infinite-ai-alerts
spec:
  groups:
  - name: infinite-ai
    interval: 30s
    rules:
    - alert: HighErrorRate
      expr: rate(http_requests_total{status="500"}[5m]) > 0.05
      annotations:
        summary: "High error rate detected"
```

### 5. Health Checks

**Implement comprehensive health checks:**

```python
@app.route('/health')
def health():
    checks = {
        'database': check_database(),
        's3': check_s3_access(),
        'model': check_model_loaded()
    }
    
    if all(checks.values()):
        return jsonify(checks), 200
    else:
        return jsonify(checks), 503
```

### 6. Dashboard

**Create comprehensive dashboards:**
- Use Grafana for visualization
- Monitor key metrics:
  - Request rate
  - Error rate
  - Latency (p50, p95, p99)
  - Resource utilization
  - Cost metrics

## Continuous Improvement

1. **Regular reviews:**
   - Monthly security audits
   - Quarterly cost reviews
   - Performance benchmarking

2. **Stay updated:**
   - Update dependencies regularly
   - Follow Kubernetes/AWS best practices
   - Monitor CVEs and patch promptly

3. **Documentation:**
   - Keep runbooks updated
   - Document incidents and resolutions
   - Maintain architecture diagrams

4. **Testing:**
   - Load testing
   - Chaos engineering
   - Disaster recovery drills

## Resources

- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [AWS EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [12-Factor App Methodology](https://12factor.net/)
- [CNCF Cloud Native Trail Map](https://github.com/cncf/trailmap)
