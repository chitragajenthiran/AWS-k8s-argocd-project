# GitOps Demo Project

A complete GitOps project demonstrating Kubernetes deployment using **Argo CD**, **Terraform**, and **Docker**.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           GitOps Workflow                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────────────┐  │
│   │  Code    │───▶│  Build   │───▶│  Push    │───▶│ Update Manifests │  │
│   │  Push    │    │  Docker  │    │  Image   │    │ (Kustomize)      │  │
│   └──────────┘    └──────────┘    └──────────┘    └────────┬─────────┘  │
│                                                             │            │
│                                                             ▼            │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │                        Git Repository                             │  │
│   │                    (Single Source of Truth)                       │  │
│   └──────────────────────────────────────────────────────────────────┘  │
│                                         │                                │
│                                         │ Watch & Sync                   │
│                                         ▼                                │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │                         Argo CD                                   │  │
│   │              (GitOps Controller in Kubernetes)                    │  │
│   └──────────────────────────────────────────────────────────────────┘  │
│                                         │                                │
│                                         │ Deploy                         │
│                                         ▼                                │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │                    Kubernetes Cluster                             │  │
│   │                    (EKS / AKS / GKE)                              │  │
│   └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
k8s-argocd-project/
├── app/                          # Application code
│   ├── main.py                   # Flask API
│   ├── requirements.txt          # Python dependencies
│   ├── Dockerfile                # Multi-stage Docker build
│   └── .dockerignore
├── k8s/                          # Kubernetes manifests
│   ├── base/                     # Base Kustomize resources
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── hpa.yaml
│   │   ├── ingress.yaml
│   │   └── kustomization.yaml
│   └── overlays/                 # Environment-specific overlays
│       ├── dev/
│       │   ├── kustomization.yaml
│       │   └── namespace.yaml
│       └── prod/
│           ├── kustomization.yaml
│           ├── namespace.yaml
│           └── pdb.yaml
├── terraform/                    # Infrastructure as Code
│   ├── aws/                      # AWS EKS configuration
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   └── azure/                    # Azure AKS configuration
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars
├── argocd/                       # Argo CD configurations
│   ├── app-of-apps.yaml          # Bootstrap application
│   ├── applications/
│   │   ├── dev-app.yaml          # Dev environment app
│   │   └── prod-app.yaml         # Prod environment app
│   ├── projects/
│   │   └── gitops-demo-project.yaml
│   └── secrets/
│       └── repo-secret.yaml.template
└── .github/workflows/            # CI/CD pipelines
    ├── gitops-pipeline.yml       # Build & deploy pipeline
    └── terraform-infra.yml       # Infrastructure pipeline
```

## Quick Start

### Prerequisites

- Docker
- Terraform >= 1.0
- kubectl
- AWS CLI or Azure CLI
- Argo CD CLI (optional)

### 1. Provision Infrastructure

**AWS EKS:**
```bash
cd terraform/aws
terraform init
terraform plan
terraform apply
```

**Azure AKS:**
```bash
cd terraform/azure
terraform init
terraform plan
terraform apply
```

### 2. Configure kubectl

**AWS:**
```bash
aws eks update-kubeconfig --region us-east-1 --name gitops-demo-dev-eks
```

**Azure:**
```bash
az aks get-credentials --resource-group gitops-demo-dev-rg --name gitops-demo-dev-aks
```

### 3. Access Argo CD

```bash
# Get Argo CD URL
kubectl get svc argocd-server -n argocd

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Login (default user: admin)
argocd login <ARGOCD_SERVER> --username admin --password <PASSWORD>
```

### 4. Deploy Applications

**Option A: Apply App-of-Apps (recommended)**
```bash
kubectl apply -f argocd/app-of-apps.yaml
```

**Option B: Deploy individual apps**
```bash
kubectl apply -f argocd/applications/dev-app.yaml
kubectl apply -f argocd/applications/prod-app.yaml
```

### 5. Monitor Deployment

```bash
# Watch application status
argocd app list
argocd app get gitops-demo-dev

# View in browser
argocd app open gitops-demo-dev
```

## GitOps Workflow

### How Deployments Work

1. **Developer pushes code** to `develop` or `main` branch
2. **GitHub Actions builds** Docker image and pushes to registry
3. **Pipeline updates** Kustomize image tag in manifests
4. **Argo CD detects** the manifest change (Git diff)
5. **Argo CD syncs** new version to Kubernetes cluster

### Branching Strategy

| Branch | Environment | Auto-Deploy |
|--------|-------------|-------------|
| `develop` | Dev | Yes |
| `main` | Production | Yes (with approval) |

## Terraform Infrastructure

### What Gets Created

| Resource | AWS | Azure |
|----------|-----|-------|
| Network | VPC, Subnets, NAT Gateway | VNet, Subnet |
| Kubernetes | EKS Cluster | AKS Cluster |
| Node Pool | Managed Node Group | Default Node Pool |
| Ingress | NGINX Ingress Controller | NGINX Ingress Controller |
| GitOps | Argo CD (Helm) | Argo CD (Helm) |

### Estimated Costs

| Environment | AWS (monthly) | Azure (monthly) |
|-------------|---------------|-----------------|
| Dev (2 nodes) | ~$100 | ~$100 |
| Prod (3 nodes) | ~$200 | ~$200 |

## Kubernetes Resources

### Base Resources

- **Deployment**: Application pods with security contexts
- **Service**: ClusterIP service for internal access
- **Ingress**: NGINX ingress for external access
- **HPA**: Auto-scaling based on CPU/memory
- **ConfigMap**: Application configuration

### Environment Overlays

| Setting | Dev | Prod |
|---------|-----|------|
| Replicas | 1 | 3 |
| CPU Request | 50m | 200m |
| Memory Request | 64Mi | 256Mi |
| Log Level | DEBUG | INFO |
| PDB | No | Yes (minAvailable: 2) |

## Argo CD Features Used

- **App-of-Apps Pattern**: Bootstrap multiple applications
- **Kustomize Integration**: Environment overlays
- **Automated Sync**: Auto-deploy on Git changes
- **Self-Heal**: Revert manual kubectl changes
- **Prune**: Delete resources removed from Git
- **Sync Waves**: Ordered deployments
- **Health Checks**: Custom health assessments

## GitHub Actions Workflows

### gitops-pipeline.yml

Triggers on code changes to build and deploy:

```
Code Push → Lint → Test → Build Image → Push to Registry → Update Manifests
```

### terraform-infra.yml

Manages infrastructure lifecycle:

```
Terraform Change → Validate → Plan → (Manual Approval) → Apply
```

## Required Secrets

### GitHub Repository Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key |
| `ARM_CLIENT_ID` | Azure Service Principal ID |
| `ARM_CLIENT_SECRET` | Azure Service Principal secret |
| `ARM_SUBSCRIPTION_ID` | Azure Subscription ID |
| `ARM_TENANT_ID` | Azure Tenant ID |
| `ARGOCD_SERVER` | Argo CD server URL |
| `ARGOCD_PASSWORD` | Argo CD admin password |

## Local Development

### Build Docker Image

```bash
cd app
docker build -t gitops-demo:local .
docker run -p 8080:8080 gitops-demo:local
```

### Test Kubernetes Manifests

```bash
# Preview dev overlay
kubectl kustomize k8s/overlays/dev

# Preview prod overlay
kubectl kustomize k8s/overlays/prod

# Apply to local cluster (e.g., minikube, kind)
kubectl apply -k k8s/overlays/dev
```

## Troubleshooting

### Argo CD Application Not Syncing

```bash
# Check app status
argocd app get gitops-demo-dev

# Force sync
argocd app sync gitops-demo-dev --force

# Check events
kubectl get events -n gitops-demo-dev
```

### Pod Not Starting

```bash
# Check pod status
kubectl get pods -n gitops-demo-dev
kubectl describe pod <pod-name> -n gitops-demo-dev
kubectl logs <pod-name> -n gitops-demo-dev
```

### Terraform State Issues

```bash
# Refresh state
terraform refresh

# Import existing resource
terraform import <resource> <id>

# Unlock state (if locked)
terraform force-unlock <lock-id>
```

## Best Practices

1. **Never kubectl apply directly** - Always go through Git
2. **Use sealed secrets** for sensitive data
3. **Enable RBAC** in Argo CD projects
4. **Set resource limits** on all containers
5. **Use pod disruption budgets** in production
6. **Enable audit logging** on the cluster
7. **Regularly rotate credentials**

## Resources

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws)
- [GitOps Principles](https://www.gitops.tech/)
