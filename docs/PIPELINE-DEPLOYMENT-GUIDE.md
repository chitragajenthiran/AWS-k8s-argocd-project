# Deploy GitOps Project Using GitHub Actions Pipeline

A complete step-by-step guide to deploy the Kubernetes + Argo CD infrastructure using **GitHub Actions CI/CD pipelines**.

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Pipeline Deployment Flow                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   INFRASTRUCTURE PIPELINE (One-time setup)                                   │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                  │
│   │   GitHub     │───▶│  Terraform   │───▶│  EKS Cluster │                  │
│   │   Actions    │    │  Apply       │    │  + Argo CD   │                  │
│   └──────────────┘    └──────────────┘    └──────────────┘                  │
│                                                                              │
│   GITOPS PIPELINE (Continuous deployment)                                    │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐             │
│   │  Code    │───▶│  Build   │───▶│  Update  │───▶│ Argo CD  │             │
│   │  Push    │    │  Docker  │    │  K8s     │    │ Auto     │             │
│   │          │    │  Image   │    │ Manifests│    │ Sync     │             │
│   └──────────┘    └──────────┘    └──────────┘    └──────────┘             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Part 1: Prerequisites

### 1.1 Required Accounts

- [x] GitHub account with your repo pushed
- [x] AWS account with admin access

### 1.2 Your Repository Structure

Your repo should have:
```
AWS-k8s-argocd-project/
├── .github/workflows/
│   ├── gitops-pipeline.yml      # App deployment
│   └── terraform-infra.yml      # Infrastructure
├── app/                          # Application code
├── k8s/                          # Kubernetes manifests
├── terraform/aws/                # EKS Terraform
└── argocd/                       # Argo CD configs
```

---

## Part 2: Configure GitHub Secrets

### Step 2.1: Create AWS IAM User for GitHub Actions

1. Go to **AWS Console** → **IAM** → **Users** → **Create user**
2. **User name**: `github-actions-terraform`
3. Click **Next**
4. Select **Attach policies directly**
5. Search and attach: `AdministratorAccess`
6. Click **Create user**

### Step 2.2: Create Access Keys

1. Click on the user `github-actions-terraform`
2. Go to **Security credentials** tab
3. Click **Create access key**
4. Select **Third-party service**
5. Check acknowledgment → **Create access key**
6. **Save both keys!** (You won't see them again)

### Step 2.3: Add Secrets to GitHub

1. Go to your GitHub repo: `https://github.com/chitragajenthiran/AWS-k8s-argocd-project`
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** for each:

| Secret Name | Value |
|-------------|-------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |

### Step 2.4: Add Repository Variables (Optional)

1. Go to **Settings** → **Secrets and variables** → **Actions** → **Variables**
2. Add:

| Variable Name | Value |
|---------------|-------|
| `AWS_REGION` | `us-east-1` |
| `ARGOCD_SYNC_ENABLED` | `true` |

---

## Part 3: Deploy Infrastructure via Pipeline

### Step 3.1: Trigger Infrastructure Pipeline

1. Go to your repo on GitHub
2. Click **Actions** tab
3. Select **"Terraform Infrastructure"** from left sidebar
4. Click **"Run workflow"** dropdown (right side)
5. Configure:
   - **Branch**: `main`
   - **Terraform action**: `plan` (first time, to preview)
   - **Cloud provider**: `aws`
6. Click **"Run workflow"**

### Step 3.2: Review the Plan

1. Click on the running workflow
2. Expand **"Terraform Plan"** job
3. Review what will be created:
   - VPC, Subnets, NAT Gateway
   - EKS Cluster
   - Node Group
   - Argo CD installation

### Step 3.3: Apply Infrastructure

1. Go to **Actions** → **"Terraform Infrastructure"**
2. Click **"Run workflow"**
3. Configure:
   - **Terraform action**: `apply`
   - **Cloud provider**: `aws`
4. Click **"Run workflow"**

⏱️ **This takes 15-20 minutes**

### Step 3.4: Verify Deployment

Check the workflow logs for outputs:
```
cluster_name = "gitops-demo-dev-eks"
configure_kubectl = "aws eks update-kubeconfig --region us-east-1 --name gitops-demo-dev-eks"
```

---

## Part 4: Access Your Cluster

Since the pipeline runs on GitHub's servers, you need a way to access your cluster.

### Option A: Use AWS CloudShell (Easiest)

1. Go to [AWS Console](https://console.aws.amazon.com)
2. Click **CloudShell** icon (top right, terminal icon)
3. Run:

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name gitops-demo-dev-eks

# Verify
kubectl get nodes

# Get Argo CD password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo ""

# Get Argo CD URL
kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Option B: Use EC2 Instance

Follow Part 2 of the EC2 guide to set up a jump box, then:
```bash
aws eks update-kubeconfig --region us-east-1 --name gitops-demo-dev-eks
kubectl get nodes
```

---

## Part 5: Access Argo CD UI

### Step 5.1: Get Credentials (from CloudShell or EC2)

```bash
# Get Argo CD LoadBalancer URL
ARGOCD_URL=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Argo CD URL: http://$ARGOCD_URL"

# Get admin password
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
echo "Password: $ARGOCD_PASS"
```

### Step 5.2: Login to Argo CD

1. Open browser: `http://<ARGOCD_URL>`
2. Username: `admin`
3. Password: (from above)

---

## Part 6: Deploy Application via GitOps Pipeline

### Step 6.1: Update Argo CD Application Config

First, update the repo URL in your Argo CD application:

**Edit `argocd/applications/dev-app.yaml`:**
```yaml
spec:
  source:
    repoURL: https://github.com/chitragajenthiran/AWS-k8s-argocd-project.git  # Your repo
    targetRevision: main
    path: k8s/overlays/dev
```

### Step 6.2: Apply Argo CD Application

From CloudShell or EC2:
```bash
kubectl apply -f argocd/applications/dev-app.yaml
```

Or add this step to the infrastructure pipeline output.

### Step 6.3: Trigger GitOps Pipeline

The GitOps pipeline triggers automatically when you:
- Push changes to `app/` folder (application code)
- Push changes to `k8s/` folder (Kubernetes manifests)
- Push to `main` or `develop` branch

**Manual trigger:**
1. Go to **Actions** → **"GitOps CI/CD Pipeline"**
2. Click **"Run workflow"**
3. Select environment: `dev` or `prod`

### Step 6.4: Watch the Pipeline

The pipeline will:
1. ✅ Build & test the Python app
2. ✅ Build Docker image
3. ✅ Push to GitHub Container Registry
4. ✅ Update Kustomize image tag
5. ✅ Commit changes back to repo
6. ✅ Argo CD auto-syncs (watches repo)

---

## Part 7: Make a Code Change (Test GitOps)

### Step 7.1: Edit Application Code

Edit `app/main.py` and change the version:
```python
APP_VERSION = os.getenv("APP_VERSION", "2.0.0")  # Changed from 1.0.0
```

### Step 7.2: Push Changes

```bash
git add .
git commit -m "feat: update app to v2.0.0"
git push
```

### Step 7.3: Watch the Magic

1. **GitHub Actions**: See the pipeline run automatically
2. **Argo CD UI**: Watch the app sync to new version
3. **kubectl**: Verify the new pods

```bash
kubectl get pods -n gitops-demo-dev -w
```

---

## Part 8: Add Argo CD Secrets to GitHub (Optional)

To enable automatic Argo CD sync from the pipeline:

### Step 8.1: Get Argo CD Server URL

```bash
kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Step 8.2: Add to GitHub Secrets

| Secret Name | Value |
|-------------|-------|
| `ARGOCD_SERVER` | The LoadBalancer URL |
| `ARGOCD_PASSWORD` | The admin password |

### Step 8.3: Enable Sync in Pipeline

Set repository variable:
- **Name**: `ARGOCD_SYNC_ENABLED`
- **Value**: `true`

---

## Part 9: Clean Up (Important!)

### Option A: Via Pipeline (Recommended)

1. Go to **Actions** → **"Terraform Infrastructure"**
2. Click **"Run workflow"**
3. Configure:
   - **Terraform action**: `destroy`
   - **Cloud provider**: `aws`
4. Click **"Run workflow"**

### Option B: Manual (from CloudShell)

```bash
# Clone repo
git clone https://github.com/chitragajenthiran/AWS-k8s-argocd-project.git
cd AWS-k8s-argocd-project/terraform/aws

# Initialize and destroy
terraform init
terraform destroy -auto-approve
```

---

## Pipeline Files Reference

### Infrastructure Pipeline (`.github/workflows/terraform-infra.yml`)

| Trigger | Action |
|---------|--------|
| Push to `terraform/` | Validate + Plan |
| Manual dispatch | Plan / Apply / Destroy |

### GitOps Pipeline (`.github/workflows/gitops-pipeline.yml`)

| Trigger | Action |
|---------|--------|
| Push to `app/` or `k8s/` | Build → Push → Update manifests |
| Manual dispatch | Deploy to dev/prod |

---

## Troubleshooting

### Pipeline fails: "Credentials not found"

1. Check GitHub Secrets are set correctly
2. Verify IAM user has correct permissions

### Pipeline fails: "Terraform state locked"

```bash
# From CloudShell, force unlock
cd terraform/aws
terraform force-unlock <LOCK_ID>
```

### Argo CD not syncing

1. Check if repo URL is correct in `dev-app.yaml`
2. Verify Argo CD can access your GitHub repo (if private, add credentials)

### Can't access Argo CD UI

1. Check LoadBalancer is ready: `kubectl get svc argocd-server -n argocd`
2. Check security groups allow HTTP/HTTPS traffic

---

## Cost Estimate

| Resource | Approximate Cost/Hour |
|----------|----------------------|
| EKS Cluster | $0.10 |
| NAT Gateway | $0.045 |
| EC2 Worker Nodes (2x t3.medium) | $0.0832 |
| **Total** | **~$0.23/hour** |

**Daily cost: ~$5.50** | **Monthly: ~$165** (if running 24/7)

💡 **Use the destroy pipeline when done!**

---

## Summary: Complete Workflow

```
1. Configure GitHub Secrets (AWS credentials)
         ↓
2. Run Terraform Infrastructure Pipeline (apply)
         ↓
3. Access Argo CD via LoadBalancer URL
         ↓
4. Apply Argo CD Application (dev-app.yaml)
         ↓
5. Push code changes to trigger GitOps Pipeline
         ↓
6. Argo CD auto-syncs new version
         ↓
7. Clean up: Run Terraform Pipeline (destroy)
```

---

## Quick Reference

```bash
# === GitHub Actions ===
# Trigger via: Repo → Actions → Select workflow → Run workflow

# === CloudShell Commands ===
aws eks update-kubeconfig --region us-east-1 --name gitops-demo-dev-eks
kubectl get nodes
kubectl get pods -n argocd
kubectl get svc argocd-server -n argocd

# === Argo CD Password ===
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```
