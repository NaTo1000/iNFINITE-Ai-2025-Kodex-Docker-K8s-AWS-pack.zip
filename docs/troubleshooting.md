# Troubleshooting Guide

This guide covers common issues and their solutions for iNFINITE AI 2025.

## Table of Contents

1. [Docker Issues](#docker-issues)
2. [Kubernetes Issues](#kubernetes-issues)
3. [AWS Issues](#aws-issues)
4. [Application Issues](#application-issues)
5. [Performance Issues](#performance-issues)

## Docker Issues

### Issue: Container won't start

**Symptoms:**
```
Error response from daemon: Container ... is not running
```

**Solutions:**

1. Check container logs:
```bash
docker-compose logs infinite-ai
```

2. Check if ports are already in use:
```bash
lsof -i :8080
lsof -i :9090
```

3. Rebuild the image:
```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Issue: Permission denied errors

**Symptoms:**
```
PermissionError: [Errno 13] Permission denied: '/models'
```

**Solutions:**

1. Ensure directories exist with correct permissions:
```bash
mkdir -p models data logs config
chmod -R 755 models data logs config
```

2. Check Docker volume mounts in `docker-compose.yml`

### Issue: Out of memory

**Symptoms:**
```
Container killed due to out of memory
```

**Solutions:**

1. Increase Docker memory limit:
```bash
# In docker-compose.yml
deploy:
  resources:
    limits:
      memory: 8G
```

2. Check system resources:
```bash
docker stats
```

## Kubernetes Issues

### Issue: Pods stuck in Pending state

**Symptoms:**
```
NAME                                    READY   STATUS    RESTARTS   AGE
infinite-ai-deployment-xxxx-yyyy        0/1     Pending   0          5m
```

**Diagnosis:**
```bash
kubectl describe pod <pod-name> -n infinite-ai
```

**Common Causes & Solutions:**

1. **Insufficient resources:**
```bash
# Check node resources
kubectl top nodes
kubectl describe nodes

# Solution: Scale up node group or reduce resource requests
```

2. **PVC not bound:**
```bash
# Check PVC status
kubectl get pvc -n infinite-ai

# Check storage class
kubectl get storageclass

# Solution: Ensure EFS/EBS CSI driver is installed
```

3. **Image pull errors:**
```bash
# Check events
kubectl get events -n infinite-ai --sort-by='.lastTimestamp'

# Solution: Check image name and registry access
```

### Issue: Pods CrashLoopBackOff

**Symptoms:**
```
NAME                                    READY   STATUS             RESTARTS   AGE
infinite-ai-deployment-xxxx-yyyy        0/1     CrashLoopBackOff   5          5m
```

**Diagnosis:**
```bash
kubectl logs <pod-name> -n infinite-ai
kubectl logs <pod-name> -n infinite-ai --previous
```

**Solutions:**

1. Check application logs for errors
2. Verify environment variables and secrets:
```bash
kubectl get configmap infinite-ai-config -n infinite-ai -o yaml
kubectl describe secret infinite-ai-secret -n infinite-ai
```

3. Check resource limits:
```bash
kubectl describe pod <pod-name> -n infinite-ai | grep -A 10 "Limits:"
```

### Issue: Service not accessible

**Symptoms:**
- Cannot connect to the service
- Connection timeout

**Diagnosis:**
```bash
# Check service
kubectl get svc -n infinite-ai
kubectl describe svc infinite-ai-service -n infinite-ai

# Check endpoints
kubectl get endpoints -n infinite-ai

# Test from within cluster
kubectl run -it --rm debug --image=busybox --restart=Never -n infinite-ai -- sh
wget -O- http://infinite-ai-service-internal:8080/health
```

**Solutions:**

1. Verify pod selector matches:
```bash
kubectl get pods -n infinite-ai --show-labels
```

2. Check network policies:
```bash
kubectl get networkpolicy -n infinite-ai
```

3. For LoadBalancer issues:
```bash
# Check AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer

# Check service annotations
kubectl describe svc infinite-ai-service -n infinite-ai
```

### Issue: Ingress not working

**Symptoms:**
- 404 or 503 errors
- Domain not resolving

**Diagnosis:**
```bash
kubectl describe ingress infinite-ai-ingress -n infinite-ai
kubectl get ingress infinite-ai-ingress -n infinite-ai -o yaml
```

**Solutions:**

1. Verify ALB Ingress Controller is installed:
```bash
kubectl get pods -n kube-system | grep alb
```

2. Check ingress annotations and certificate ARN

3. Verify DNS configuration:
```bash
nslookup your-domain.com
dig your-domain.com
```

4. Check ALB in AWS Console:
   - EC2 → Load Balancers
   - Check target health

### Issue: HPA not scaling

**Symptoms:**
- Pods not scaling despite high load

**Diagnosis:**
```bash
kubectl get hpa -n infinite-ai
kubectl describe hpa infinite-ai-hpa -n infinite-ai
```

**Solutions:**

1. Verify metrics-server is installed:
```bash
kubectl get deployment metrics-server -n kube-system
kubectl top pods -n infinite-ai
```

2. Check resource requests are set in deployment

3. Verify metric values:
```bash
kubectl get hpa -n infinite-ai -w
```

## AWS Issues

### Issue: EKS cluster creation fails

**Symptoms:**
- CloudFormation stack fails
- Terraform errors

**Solutions:**

1. Check AWS service limits:
   - VPCs per region
   - Elastic IPs
   - EKS clusters

2. Verify IAM permissions:
```bash
aws sts get-caller-identity
aws iam get-user
```

3. Check CloudFormation events:
```bash
aws cloudformation describe-stack-events \
  --stack-name infinite-ai-stack \
  --region us-east-1
```

### Issue: Node group not scaling

**Symptoms:**
- Nodes not joining cluster
- Auto-scaling not working

**Diagnosis:**
```bash
# Check node group
aws eks describe-nodegroup \
  --cluster-name infinite-ai-cluster \
  --nodegroup-name infinite-ai-node-group

# Check nodes
kubectl get nodes
```

**Solutions:**

1. Check node IAM role permissions
2. Verify auto-scaling group settings in AWS Console
3. Check cluster autoscaler logs:
```bash
kubectl logs -n kube-system deployment/cluster-autoscaler
```

### Issue: S3 access denied

**Symptoms:**
```
An error occurred (AccessDenied) when calling the PutObject operation
```

**Solutions:**

1. Verify IAM role for service account:
```bash
kubectl describe sa infinite-ai-sa -n infinite-ai
```

2. Check IAM role trust policy and permissions

3. Verify pod has correct role annotation:
```bash
kubectl get sa infinite-ai-sa -n infinite-ai -o yaml
```

### Issue: CloudWatch logs not appearing

**Solutions:**

1. Verify FluentBit/FluentD is running:
```bash
kubectl get pods -n amazon-cloudwatch
```

2. Check IAM permissions for worker nodes

3. Verify log group exists:
```bash
aws logs describe-log-groups --region us-east-1
```

## Application Issues

### Issue: Health check failing

**Diagnosis:**
```bash
# Test health endpoint
kubectl port-forward -n infinite-ai svc/infinite-ai-service-internal 8080:8080
curl http://localhost:8080/health
```

**Solutions:**

1. Check application logs for startup errors
2. Verify all dependencies are available
3. Check if models are loaded correctly

### Issue: High latency

**Diagnosis:**
```bash
# Check resource usage
kubectl top pods -n infinite-ai

# Check application logs
kubectl logs -f deployment/infinite-ai-deployment -n infinite-ai
```

**Solutions:**

1. Increase replica count
2. Increase resource limits
3. Enable horizontal pod autoscaling
4. Check network latency to S3

### Issue: Out of memory errors

**Solutions:**

1. Increase memory limits:
```yaml
resources:
  limits:
    memory: "8Gi"
```

2. Reduce batch size or concurrent workers

3. Enable memory profiling

## Performance Issues

### Issue: Slow model inference

**Solutions:**

1. Use GPU instances (p3, g4 instance types)
2. Optimize model loading
3. Implement caching with Redis
4. Use model quantization

### Issue: High CPU usage

**Diagnosis:**
```bash
kubectl top pods -n infinite-ai
kubectl exec -it <pod-name> -n infinite-ai -- top
```

**Solutions:**

1. Scale horizontally (more replicas)
2. Use larger instance types
3. Optimize application code
4. Enable CPU-based autoscaling

## Getting Additional Help

If you still have issues:

1. Check application logs:
```bash
kubectl logs -f deployment/infinite-ai-deployment -n infinite-ai --tail=100
```

2. Check all events:
```bash
kubectl get events -n infinite-ai --sort-by='.lastTimestamp'
```

3. Export diagnostics:
```bash
kubectl describe all -n infinite-ai > diagnostics.txt
```

4. Review AWS CloudWatch logs in the AWS Console

5. Open an issue on GitHub with:
   - Detailed error messages
   - Deployment method used
   - Relevant logs
   - Environment details

## Useful Commands Reference

```bash
# Restart all pods
kubectl rollout restart deployment/infinite-ai-deployment -n infinite-ai

# Force delete stuck pod
kubectl delete pod <pod-name> -n infinite-ai --grace-period=0 --force

# Get all resources
kubectl get all -n infinite-ai

# Tail logs from all pods
kubectl logs -f deployment/infinite-ai-deployment -n infinite-ai --all-containers=true

# Execute into pod
kubectl exec -it <pod-name> -n infinite-ai -- /bin/bash

# Port forward for debugging
kubectl port-forward -n infinite-ai svc/infinite-ai-service-internal 8080:8080
```
