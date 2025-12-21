#!/bin/bash
# Cleanup script for iNFINITE AI 2025
# Usage: ./cleanup.sh [deployment-type]
# Example: ./cleanup.sh kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
DEPLOYMENT_TYPE=${1:-kubernetes}
CLUSTER_NAME="infinite-ai-cluster"
NAMESPACE="infinite-ai"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}iNFINITE AI 2025 Cleanup Script${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "Deployment Type: $DEPLOYMENT_TYPE"
echo ""

# Confirmation prompt
read -p "Are you sure you want to cleanup $DEPLOYMENT_TYPE resources? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Function to cleanup Docker resources
cleanup_docker() {
    echo -e "${YELLOW}Cleaning up Docker resources...${NC}"
    
    # Stop and remove containers
    echo "Stopping containers..."
    docker-compose down
    
    # Remove volumes (optional)
    read -p "Remove volumes? (yes/no): " REMOVE_VOLUMES
    if [ "$REMOVE_VOLUMES" = "yes" ]; then
        docker-compose down -v
        echo -e "${GREEN}✓ Volumes removed${NC}"
    fi
    
    # Remove images (optional)
    read -p "Remove images? (yes/no): " REMOVE_IMAGES
    if [ "$REMOVE_IMAGES" = "yes" ]; then
        docker rmi infinite-ai:latest || true
        echo -e "${GREEN}✓ Images removed${NC}"
    fi
    
    echo -e "${GREEN}✓ Docker cleanup completed${NC}"
}

# Function to cleanup Kubernetes resources
cleanup_kubernetes() {
    echo -e "${YELLOW}Cleaning up Kubernetes resources...${NC}"
    
    # Update kubeconfig
    aws eks update-kubeconfig --name $CLUSTER_NAME --region us-east-1 || true
    
    # Delete resources in order
    echo "Deleting Kubernetes resources..."
    
    kubectl delete -f k8s/network-policy.yaml --ignore-not-found=true
    kubectl delete -f k8s/hpa.yaml --ignore-not-found=true
    kubectl delete -f k8s/ingress.yaml --ignore-not-found=true
    kubectl delete -f k8s/service.yaml --ignore-not-found=true
    kubectl delete -f k8s/deployment.yaml --ignore-not-found=true
    kubectl delete -f k8s/secret.yaml --ignore-not-found=true
    kubectl delete -f k8s/configmap.yaml --ignore-not-found=true
    
    # Delete namespace (optional)
    read -p "Delete namespace $NAMESPACE? (yes/no): " DELETE_NAMESPACE
    if [ "$DELETE_NAMESPACE" = "yes" ]; then
        kubectl delete namespace $NAMESPACE --ignore-not-found=true
        echo -e "${GREEN}✓ Namespace deleted${NC}"
    fi
    
    echo -e "${GREEN}✓ Kubernetes cleanup completed${NC}"
}

# Function to cleanup AWS infrastructure
cleanup_aws_infrastructure() {
    echo -e "${YELLOW}Cleaning up AWS infrastructure...${NC}"
    
    cd aws/terraform
    
    # Destroy infrastructure
    echo "Destroying Terraform-managed infrastructure..."
    terraform destroy -auto-approve
    
    echo -e "${GREEN}✓ AWS infrastructure cleanup completed${NC}"
    
    cd ../..
}

# Function to cleanup CloudFormation stack
cleanup_cloudformation() {
    echo -e "${YELLOW}Cleaning up CloudFormation stack...${NC}"
    
    STACK_NAME="infinite-ai-stack"
    
    echo "Deleting CloudFormation stack: $STACK_NAME"
    aws cloudformation delete-stack --stack-name $STACK_NAME
    
    echo "Waiting for stack deletion..."
    aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME
    
    echo -e "${GREEN}✓ CloudFormation stack deleted${NC}"
}

# Main execution
main() {
    case $DEPLOYMENT_TYPE in
        docker)
            cleanup_docker
            ;;
        kubernetes|k8s)
            cleanup_kubernetes
            ;;
        aws|terraform)
            cleanup_aws_infrastructure
            ;;
        cloudformation|cfn)
            cleanup_cloudformation
            ;;
        all)
            cleanup_kubernetes
            cleanup_aws_infrastructure
            cleanup_docker
            ;;
        *)
            echo -e "${RED}Unknown deployment type: $DEPLOYMENT_TYPE${NC}"
            echo "Valid options: docker, kubernetes (k8s), aws (terraform), cloudformation (cfn), all"
            exit 1
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Cleanup completed successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# Run main function
main
