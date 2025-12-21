# iNFINITE AI 2025 - Kodex Docker K8s AWS Pack

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Docker](https://img.shields.io/badge/docker-ready-brightgreen.svg)
![Kubernetes](https://img.shields.io/badge/kubernetes-compatible-326CE5.svg)
![AWS](https://img.shields.io/badge/AWS-supported-FF9900.svg)

A comprehensive cloud-based AI deployment package with enhancements to run in AWS cloud with tool access. This pack provides Docker containerization, Kubernetes orchestration, and AWS cloud infrastructure templates for deploying AI workloads at scale.

## 🚀 Features

- **Docker Support**: Pre-configured Dockerfiles and docker-compose for local development and testing
- **Kubernetes Ready**: Production-grade K8s manifests for scalable deployments
- **AWS Integration**: CloudFormation templates and Terraform configurations for AWS infrastructure
- **AI/ML Optimized**: Configured for GPU support and high-performance computing
- **Monitoring & Logging**: Built-in observability with Prometheus and CloudWatch
- **Security First**: Best practices for secrets management and network policies
- **Auto-scaling**: Horizontal Pod Autoscaling and AWS Auto Scaling Groups
- **Multi-environment**: Support for dev, staging, and production environments

## 📋 Prerequisites

- Docker 20.10+
- Kubernetes 1.24+
- kubectl CLI
- AWS CLI 2.x
- Terraform 1.5+ (optional)
- An AWS account with appropriate permissions

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│              AWS Cloud (VPC)                     │
│  ┌──────────────────────────────────────────┐  │
│  │      Amazon EKS Cluster                   │  │
│  │  ┌────────────┐  ┌────────────┐          │  │
│  │  │   AI Pod   │  │   AI Pod   │          │  │
│  │  │ (Container)│  │ (Container)│          │  │
│  │  └────────────┘  └────────────┘          │  │
│  │         │              │                   │  │
│  │    ┌────┴──────────────┴────┐            │  │
│  │    │   Kubernetes Service    │            │  │
│  │    └────────────────────────┘            │  │
│  └──────────────────────────────────────────┘  │
│                     │                            │
│         ┌───────────┴───────────┐               │
│         │   Application LB      │               │
│         └───────────────────────┘               │
│                                                   │
│  ┌──────────────┐  ┌──────────────┐            │
│  │  CloudWatch  │  │    S3 for    │            │
│  │  Monitoring  │  │   ML Models  │            │
│  └──────────────┘  └──────────────┘            │
└─────────────────────────────────────────────────┘
```

## 🚦 Quick Start

### Local Development with Docker

```bash
# Clone the repository
git clone https://github.com/NaTo1000/iNFINITE-Ai-2025-Kodex-Docker-K8s-AWS-pack.zip.git
cd iNFINITE-Ai-2025-Kodex-Docker-K8s-AWS-pack.zip

# Build the Docker image
docker build -t infinite-ai:latest .

# Run with docker-compose
docker-compose up -d

# Check logs
docker-compose logs -f
```

### Deploy to Kubernetes

```bash
# Configure kubectl for your cluster
aws eks update-kubeconfig --name infinite-ai-cluster --region us-east-1

# Apply Kubernetes manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml

# Check deployment status
kubectl get pods -n infinite-ai
```

### Deploy AWS Infrastructure

#### Using CloudFormation:

```bash
# Deploy the infrastructure
aws cloudformation create-stack \
  --stack-name infinite-ai-stack \
  --template-body file://aws/cloudformation/infrastructure.yaml \
  --parameters file://aws/cloudformation/parameters.json \
  --capabilities CAPABILITY_IAM

# Monitor stack creation
aws cloudformation describe-stacks --stack-name infinite-ai-stack
```

#### Using Terraform:

```bash
cd aws/terraform

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -out=tfplan

# Apply the configuration
terraform apply tfplan
```

## 📁 Project Structure

```
.
├── README.md                      # This file
├── Dockerfile                     # Docker image definition
├── docker-compose.yml            # Local development setup
├── .dockerignore                 # Docker ignore patterns
├── k8s/                          # Kubernetes manifests
│   ├── namespace.yaml            # Namespace definition
│   ├── configmap.yaml            # Configuration data
│   ├── secret.yaml               # Sensitive data
│   ├── deployment.yaml           # Pod deployment
│   ├── service.yaml              # Service exposure
│   ├── ingress.yaml              # Ingress rules
│   ├── hpa.yaml                  # Horizontal Pod Autoscaler
│   └── network-policy.yaml       # Network policies
├── aws/                          # AWS configurations
│   ├── cloudformation/           # CloudFormation templates
│   │   ├── infrastructure.yaml   # Main infrastructure
│   │   └── parameters.json       # Stack parameters
│   └── terraform/                # Terraform configs
│       ├── main.tf               # Main configuration
│       ├── variables.tf          # Variable definitions
│       ├── outputs.tf            # Output values
│       └── versions.tf           # Provider versions
├── scripts/                      # Helper scripts
│   ├── deploy.sh                 # Deployment script
│   ├── cleanup.sh                # Cleanup script
│   └── health-check.sh           # Health check script
└── docs/                         # Additional documentation
    ├── deployment-guide.md       # Deployment guide
    ├── troubleshooting.md        # Troubleshooting tips
    └── best-practices.md         # Best practices
```

## 🔧 Configuration

### Environment Variables

The application supports the following environment variables:

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `AI_MODEL_PATH` | Path to AI model files | `/models` | Yes |
| `AWS_REGION` | AWS region for deployment | `us-east-1` | Yes |
| `LOG_LEVEL` | Logging level | `INFO` | No |
| `MAX_WORKERS` | Maximum worker threads | `4` | No |
| `ENABLE_GPU` | Enable GPU support | `false` | No |
| `S3_BUCKET` | S3 bucket for model storage | - | Yes |
| `METRICS_PORT` | Port for metrics endpoint | `9090` | No |

### Kubernetes Configuration

Edit `k8s/configmap.yaml` to customize application settings:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: infinite-ai-config
data:
  AI_MODEL_PATH: "/models"
  LOG_LEVEL: "INFO"
  AWS_REGION: "us-east-1"
```

### AWS Configuration

Edit `aws/terraform/variables.tf` or `aws/cloudformation/parameters.json` to customize infrastructure:

- VPC CIDR range
- Instance types
- Auto-scaling parameters
- Security group rules

## 🔐 Security Best Practices

1. **Secrets Management**: Use AWS Secrets Manager or Kubernetes Secrets
2. **IAM Roles**: Follow principle of least privilege
3. **Network Policies**: Implement strict network segmentation
4. **Image Scanning**: Scan Docker images for vulnerabilities
5. **Encryption**: Enable encryption at rest and in transit
6. **Audit Logging**: Enable CloudTrail and K8s audit logs

## 📊 Monitoring & Observability

### CloudWatch Integration

The deployment automatically creates CloudWatch log groups and metrics:

- Application logs: `/aws/eks/infinite-ai/application`
- Container insights enabled
- Custom metrics for AI inference performance

### Prometheus Metrics

Metrics endpoint available at `:9090/metrics`:

- Request latency
- Throughput
- Error rates
- GPU utilization (if enabled)

## 🔄 CI/CD Integration

The pack includes GitHub Actions workflows for:

- Automated testing
- Docker image building
- Security scanning
- Deployment to staging/production

See `.github/workflows/` for details.

## 🐛 Troubleshooting

### Common Issues

**Issue**: Pods not starting
```bash
kubectl describe pod <pod-name> -n infinite-ai
kubectl logs <pod-name> -n infinite-ai
```

**Issue**: AWS resources not created
```bash
aws cloudformation describe-stack-events --stack-name infinite-ai-stack
```

**Issue**: Connection refused
```bash
kubectl port-forward service/infinite-ai-service 8080:80 -n infinite-ai
```

For more troubleshooting tips, see [docs/troubleshooting.md](docs/troubleshooting.md).

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- AWS for cloud infrastructure
- Kubernetes community
- Docker for containerization
- All contributors and users

## 📞 Support

- 📧 Email: support@infinite-ai.example.com
- 💬 Discord: [Join our community](https://discord.gg/infinite-ai)
- 📖 Documentation: [https://docs.infinite-ai.example.com](https://docs.infinite-ai.example.com)
- 🐛 Issues: [GitHub Issues](https://github.com/NaTo1000/iNFINITE-Ai-2025-Kodex-Docker-K8s-AWS-pack.zip/issues)

---

**Made with ❤️ for the AI/ML community**
