#!/bin/bash
# Deployment script for iNFINITE AI 2025
# Usage: ./deploy.sh [environment] [deployment-type]
# Example: ./deploy.sh production kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT=${1:-production}
DEPLOYMENT_TYPE=${2:-kubernetes}
CLUSTER_NAME="infinite-ai-cluster"
NAMESPACE="infinite-ai"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}iNFINITE AI 2025 Deployment Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Environment: $ENVIRONMENT"
echo "Deployment Type: $DEPLOYMENT_TYPE"
echo ""

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}kubectl is not installed. Please install kubectl.${NC}"
        exit 1
    fi
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}AWS CLI is not installed. Please install AWS CLI.${NC}"
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed. Please install Docker.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ All prerequisites satisfied${NC}"
    echo ""
}

# Function to deploy with Docker Compose
deploy_docker() {
    echo -e "${YELLOW}Deploying with Docker Compose...${NC}"
    
    # Build the Docker image
    echo "Building Docker image..."
    docker build -t infinite-ai:latest .
    
    # Start services
    echo "Starting services..."
    docker-compose up -d
    
    # Wait for services to be ready
    echo "Waiting for services to be ready..."
    sleep 10
    
    # Check health
    if docker-compose ps | grep -q "Up"; then
        echo -e "${GREEN}✓ Services deployed successfully${NC}"
        echo ""
        echo "Application URL: http://localhost:8080"
        echo "Metrics URL: http://localhost:9090"
    else
        echo -e "${RED}✗ Service deployment failed${NC}"
        docker-compose logs
        exit 1
    fi
}

# Function to deploy to Kubernetes
deploy_kubernetes() {
    echo -e "${YELLOW}Deploying to Kubernetes...${NC}"
    
    # Update kubeconfig
    echo "Updating kubeconfig..."
    aws eks update-kubeconfig --name $CLUSTER_NAME --region us-east-1
    
    # Create namespace
    echo "Creating namespace..."
    kubectl apply -f k8s/namespace.yaml
    
    # Apply ConfigMap
    echo "Applying ConfigMap..."
    kubectl apply -f k8s/configmap.yaml
    
    # Apply Secrets (ensure secrets are properly configured)
    echo "Applying Secrets..."
    kubectl apply -f k8s/secret.yaml
    
    # Apply Deployment
    echo "Deploying application..."
    kubectl apply -f k8s/deployment.yaml
    
    # Apply Service
    echo "Creating service..."
    kubectl apply -f k8s/service.yaml
    
    # Apply Ingress
    echo "Creating ingress..."
    kubectl apply -f k8s/ingress.yaml
    
    # Apply HPA
    echo "Configuring autoscaling..."
    kubectl apply -f k8s/hpa.yaml
    
    # Apply Network Policy
    echo "Applying network policies..."
    kubectl apply -f k8s/network-policy.yaml
    
    # Wait for deployment to be ready
    echo "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s \
        deployment/infinite-ai-deployment -n $NAMESPACE
    
    # Get service endpoint
    echo ""
    echo -e "${GREEN}✓ Kubernetes deployment completed${NC}"
    echo ""
    echo "Getting service endpoint..."
    kubectl get service infinite-ai-service -n $NAMESPACE
    
    echo ""
    echo "To view pods:"
    echo "  kubectl get pods -n $NAMESPACE"
    echo ""
    echo "To view logs:"
    echo "  kubectl logs -f deployment/infinite-ai-deployment -n $NAMESPACE"
}

# Function to deploy AWS infrastructure
deploy_aws_infrastructure() {
    echo -e "${YELLOW}Deploying AWS infrastructure with Terraform...${NC}"
    
    cd aws/terraform
    
    # Initialize Terraform
    echo "Initializing Terraform..."
    terraform init
    
    # Validate configuration
    echo "Validating Terraform configuration..."
    terraform validate
    
    # Plan deployment
    echo "Planning deployment..."
    terraform plan -out=tfplan
    
    # Apply configuration
    echo "Applying Terraform configuration..."
    terraform apply tfplan
    
    # Get outputs
    echo ""
    echo -e "${GREEN}✓ AWS infrastructure deployed${NC}"
    echo ""
    terraform output
    
    cd ../..
}

# Main execution
main() {
    check_prerequisites
    
    case $DEPLOYMENT_TYPE in
        docker)
            deploy_docker
            ;;
        kubernetes|k8s)
            deploy_kubernetes
            ;;
        aws)
            deploy_aws_infrastructure
            ;;
        full)
            deploy_aws_infrastructure
            deploy_kubernetes
            ;;
        *)
            echo -e "${RED}Unknown deployment type: $DEPLOYMENT_TYPE${NC}"
            echo "Valid options: docker, kubernetes (k8s), aws, full"
            exit 1
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Deployment completed successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# Run main function
main
