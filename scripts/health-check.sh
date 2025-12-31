#!/bin/bash
# Health check script for iNFINITE AI 2025
# Usage: ./health-check.sh [deployment-type]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

DEPLOYMENT_TYPE=${1:-kubernetes}
NAMESPACE="infinite-ai"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}iNFINITE AI 2025 Health Check${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Function to check Docker deployment
check_docker() {
    echo -e "${YELLOW}Checking Docker deployment...${NC}"
    echo ""
    
    # Check if containers are running
    if docker-compose ps | grep -q "Up"; then
        echo -e "${GREEN}✓ Containers are running${NC}"
        docker-compose ps
        echo ""
        
        # Check application health
        echo "Checking application health..."
        if curl -f -s http://localhost:8080/health > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Application is healthy${NC}"
        else
            echo -e "${RED}✗ Application health check failed${NC}"
            return 1
        fi
        
        # Check metrics endpoint
        echo "Checking metrics endpoint..."
        if curl -f -s http://localhost:9090/metrics > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Metrics endpoint is accessible${NC}"
        else
            echo -e "${YELLOW}⚠ Metrics endpoint is not accessible${NC}"
        fi
    else
        echo -e "${RED}✗ Containers are not running${NC}"
        docker-compose ps
        return 1
    fi
}

# Function to check Kubernetes deployment
check_kubernetes() {
    echo -e "${YELLOW}Checking Kubernetes deployment...${NC}"
    echo ""
    
    # Check if namespace exists
    if kubectl get namespace $NAMESPACE > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Namespace exists${NC}"
    else
        echo -e "${RED}✗ Namespace does not exist${NC}"
        return 1
    fi
    
    # Check pods
    echo ""
    echo "Pod Status:"
    kubectl get pods -n $NAMESPACE
    
    READY_PODS=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -o "True" | wc -l)
    TOTAL_PODS=$(kubectl get pods -n $NAMESPACE --no-headers | wc -l)
    
    echo ""
    if [ "$READY_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
        echo -e "${GREEN}✓ All pods are ready ($READY_PODS/$TOTAL_PODS)${NC}"
    else
        echo -e "${RED}✗ Not all pods are ready ($READY_PODS/$TOTAL_PODS)${NC}"
    fi
    
    # Check deployment
    echo ""
    echo "Deployment Status:"
    kubectl get deployment -n $NAMESPACE
    
    # Check services
    echo ""
    echo "Service Status:"
    kubectl get service -n $NAMESPACE
    
    # Check HPA
    echo ""
    echo "HPA Status:"
    kubectl get hpa -n $NAMESPACE || echo "HPA not found"
    
    # Check ingress
    echo ""
    echo "Ingress Status:"
    kubectl get ingress -n $NAMESPACE || echo "Ingress not found"
    
    # Test service endpoint
    echo ""
    echo "Testing service endpoint..."
    SERVICE_IP=$(kubectl get service infinite-ai-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ -n "$SERVICE_IP" ]; then
        echo "Service endpoint: $SERVICE_IP"
        if curl -f -s --max-time 5 http://$SERVICE_IP/health > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Service endpoint is accessible${NC}"
        else
            echo -e "${YELLOW}⚠ Service endpoint health check timed out or failed${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Service endpoint not yet available${NC}"
    fi
    
    # Check recent pod logs for errors
    echo ""
    echo "Checking recent logs for errors..."
    POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=infinite-ai-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$POD_NAME" ]; then
        ERROR_COUNT=$(kubectl logs --tail=100 $POD_NAME -n $NAMESPACE 2>/dev/null | grep -i "error" | wc -l)
        if [ "$ERROR_COUNT" -gt 0 ]; then
            echo -e "${YELLOW}⚠ Found $ERROR_COUNT error(s) in recent logs${NC}"
        else
            echo -e "${GREEN}✓ No errors in recent logs${NC}"
        fi
    fi
}

# Function to check AWS resources
check_aws() {
    echo -e "${YELLOW}Checking AWS resources...${NC}"
    echo ""
    
    CLUSTER_NAME="infinite-ai-cluster"
    
    # Check EKS cluster
    echo "EKS Cluster Status:"
    aws eks describe-cluster --name $CLUSTER_NAME --query 'cluster.status' --output text 2>/dev/null || echo "Cluster not found"
    
    # Check node group
    echo ""
    echo "Node Group Status:"
    aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name ${CLUSTER_NAME}-node-group --query 'nodegroup.status' --output text 2>/dev/null || echo "Node group not found"
    
    # Check S3 bucket
    echo ""
    echo "S3 Bucket Status:"
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    aws s3 ls ${CLUSTER_NAME}-models-${ACCOUNT_ID} > /dev/null 2>&1 && echo -e "${GREEN}✓ S3 bucket exists${NC}" || echo -e "${YELLOW}⚠ S3 bucket not found${NC}"
}

# Main execution
main() {
    case $DEPLOYMENT_TYPE in
        docker)
            check_docker
            ;;
        kubernetes|k8s)
            check_kubernetes
            ;;
        aws)
            check_aws
            check_kubernetes
            ;;
        *)
            echo -e "${RED}Unknown deployment type: $DEPLOYMENT_TYPE${NC}"
            echo "Valid options: docker, kubernetes (k8s), aws"
            exit 1
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Health check completed!${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# Run main function
main
