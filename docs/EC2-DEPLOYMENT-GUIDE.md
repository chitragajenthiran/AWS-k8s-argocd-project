# Deploy GitOps Project from AWS EC2 Instance

A complete step-by-step guide to deploy the Kubernetes + Argo CD infrastructure from an EC2 instance.

## Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Deployment Setup                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌──────────────┐         ┌──────────────────────────┐     │
│   │   EC2        │         │   EKS Cluster            │     │
│   │   Instance   │────────▶│   + Argo CD              │     │
│   │   (Jump Box) │         │   + Your App             │     │
│   └──────────────┘         └──────────────────────────┘     │
│         │                                                    │
│         │ You connect via SSH                               │
│         ▼                                                    │
│   ┌──────────────┐                                          │
│   │   Your PC    │                                          │
│   │   (Browser)  │                                          │
│   └──────────────┘                                          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Part 1: Create EC2 Instance (AWS Console)

### Step 1.1: Launch EC2 Instance

1. Go to [AWS Console](https://console.aws.amazon.com/ec2)
2. Click **Launch Instance**
3. Configure:

| Setting | Value |
|---------|-------|
| Name | `terraform-jumpbox` |
| AMI | Amazon Linux 2023 |
| Instance Type | `t3.medium` (2 vCPU, 4GB RAM) |
| Key Pair | Create new or use existing |
| Network | Default VPC |
| Security Group | Create new (see below) |
| Storage | 30 GB gp3 |

### Step 1.2: Security Group Rules

Create these inbound rules:

| Type | Port | Source | Purpose |
|------|------|--------|---------|
| SSH | 22 | Your IP | SSH access |
| Custom TCP | 8080 | Your IP | Port forwarding (Argo CD) |

### Step 1.3: IAM Role for EC2

1. Go to **IAM** → **Roles** → **Create Role**
2. Select **AWS Service** → **EC2**
3. Attach these policies:
   - `AdministratorAccess` (for learning; use least-privilege in production)
4. Name: `EC2-Terraform-Role`
5. Attach to EC2: **Actions** → **Security** → **Modify IAM Role**

---

## Part 2: Connect to EC2 & Install Tools

### Step 2.1: SSH into EC2

```bash
# From your local machine (Windows PowerShell or Git Bash)
ssh -i "your-key.pem" ec2-user@<EC2-PUBLIC-IP>
```

### Step 2.2: Install Required Tools

Copy and paste this entire script:

```bash
#!/bin/bash
set -e

echo "=========================================="
echo "Installing DevOps Tools on Amazon Linux"
echo "=========================================="

# Update system
sudo yum update -y

# Install Git
sudo yum install -y git

# Install Terraform
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum install -y terraform

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Install AWS CLI v2 (usually pre-installed on Amazon Linux 2023)
if ! command -v aws &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
fi

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Argo CD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Install Docker (optional - for local builds)
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Verify installations
echo ""
echo "=========================================="
echo "Installed Versions:"
echo "=========================================="
terraform version
kubectl version --client
aws --version
helm version
argocd version --client
docker --version

echo ""
echo "✅ All tools installed successfully!"
echo "⚠️  Log out and back in for Docker permissions"
```

Save as `install-tools.sh` and run:
```bash
chmod +x install-tools.sh
./install-tools.sh
```

### Step 2.3: Verify AWS Credentials

```bash
# Check if IAM role is attached
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AROAXXXXXXXXXX:i-0123456789",
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/EC2-Terraform-Role/i-0123456789"
}
```

---

## Part 3: Clone & Deploy Infrastructure

### Step 3.1: Clone the Repository

```bash
# Clone your repo (replace with your GitHub URL)
git clone https://github.com/YOUR_USERNAME/terraform-learn.git
cd terraform-learn/k8s-argocd-project/terraform/aws
```

Or upload files manually:
```bash
# From your local machine
scp -i "your-key.pem" -r k8s-argocd-project ec2-user@<EC2-IP>:~/
```

### Step 3.2: Initialize Terraform

```bash
cd ~/terraform-learn/k8s-argocd-project/terraform/aws

# Initialize Terraform
terraform init
```

### Step 3.3: Review the Plan

```bash
# See what will be created
terraform plan
```

Review the output. You should see:
- VPC with subnets
- EKS cluster
- Node group
- Argo CD installation

### Step 3.4: Deploy Infrastructure

```bash
# Create everything (takes 15-20 minutes)
terraform apply
```

Type `yes` when prompted.

**Expected output:**
```
Apply complete! Resources: 50 added, 0 changed, 0 destroyed.

Outputs:

cluster_name = "gitops-demo-dev-eks"
configure_kubectl = "aws eks update-kubeconfig --region us-east-1 --name gitops-demo-dev-eks"
argocd_initial_password = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
```

---

## Part 4: Configure kubectl & Access Cluster

### Step 4.1: Configure kubectl

```bash
# Run the command from terraform output
aws eks update-kubeconfig --region us-east-1 --name gitops-demo-dev-eks
```

### Step 4.2: Verify Cluster Access

```bash
# Check nodes
kubectl get nodes

# Expected output:
# NAME                          STATUS   ROLES    AGE   VERSION
# ip-10-0-1-xxx.ec2.internal   Ready    <none>   5m    v1.28.x
# ip-10-0-2-xxx.ec2.internal   Ready    <none>   5m    v1.28.x
```

### Step 4.3: Check Argo CD Installation

```bash
# Check Argo CD pods
kubectl get pods -n argocd

# All pods should be Running
# NAME                                  READY   STATUS    RESTARTS   AGE
# argocd-server-xxx                     1/1     Running   0          5m
# argocd-repo-server-xxx                1/1     Running   0          5m
# argocd-application-controller-xxx     1/1     Running   0          5m
```

---

## Part 5: Access Argo CD UI

### Step 5.1: Get Argo CD Password

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo ""
```

**Save this password!**

### Step 5.2: Get Argo CD URL

**Option A: LoadBalancer (may take 2-3 minutes)**
```bash
# Get the LoadBalancer URL
kubectl get svc argocd-server -n argocd

# Output:
# NAME            TYPE           CLUSTER-IP     EXTERNAL-IP                              PORT(S)
# argocd-server   LoadBalancer   10.100.x.x     abc123.us-east-1.elb.amazonaws.com       80:30080/TCP,443:30443/TCP
```

Access via: `http://<EXTERNAL-IP>`

**Option B: Port Forward (from EC2)**
```bash
# Run in background
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0 &
```

Then access via: `https://<EC2-PUBLIC-IP>:8080`

### Step 5.3: Login to Argo CD

1. Open browser: `http://<ARGOCD-URL>`
2. Username: `admin`
3. Password: (from Step 5.1)

---

## Part 6: Deploy Your Application

### Step 6.1: Apply Argo CD Application

```bash
cd ~/terraform-learn/k8s-argocd-project

# Deploy the dev application
kubectl apply -f argocd/applications/dev-app.yaml
```

**Note:** Update the `repoURL` in the YAML file first:
```bash
# Edit the file
vi argocd/applications/dev-app.yaml

# Change this line:
#   repoURL: https://github.com/YOUR_ORG/gitops-demo.git
# To your actual repo URL
```

### Step 6.2: Watch Deployment in Argo CD

```bash
# Using CLI
argocd login <ARGOCD-URL> --username admin --password <PASSWORD> --insecure
argocd app list
argocd app get gitops-demo-dev
```

Or use the Argo CD Web UI to see real-time sync status.

---

## Part 7: Clean Up (Important!)

**To avoid AWS charges, destroy resources when done:**

```bash
cd ~/terraform-learn/k8s-argocd-project/terraform/aws

# Destroy all resources
terraform destroy
```

Type `yes` when prompted.

**Also stop/terminate your EC2 instance.**

---

## Troubleshooting

### Error: "You must be logged in to the server"
```bash
# Re-configure kubectl
aws eks update-kubeconfig --region us-east-1 --name gitops-demo-dev-eks
```

### Error: "Cannot create cluster, insufficient permissions"
```bash
# Check IAM role
aws sts get-caller-identity

# Ensure AdministratorAccess is attached to EC2 role
```

### Argo CD pods not starting
```bash
# Check pod events
kubectl describe pods -n argocd

# Check logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

### Terraform init fails
```bash
# Clear cache and retry
rm -rf .terraform .terraform.lock.hcl
terraform init
```

---

## Cost Estimate

| Resource | Approximate Cost/Hour |
|----------|----------------------|
| EC2 t3.medium | $0.0416 |
| EKS Cluster | $0.10 |
| NAT Gateway | $0.045 |
| EC2 Worker Nodes (2x t3.medium) | $0.0832 |
| **Total** | **~$0.27/hour** |

**Daily cost: ~$6.50** | **Monthly: ~$195** (if running 24/7)

💡 **Tip:** Destroy resources after learning to avoid charges!

---

## Quick Reference Commands

```bash
# === Terraform ===
terraform init          # Initialize
terraform plan          # Preview
terraform apply         # Create
terraform destroy       # Delete all

# === kubectl ===
kubectl get nodes                    # List nodes
kubectl get pods -A                  # All pods
kubectl get svc -n argocd           # Argo CD service

# === Argo CD ===
argocd app list                     # List apps
argocd app sync <app-name>          # Force sync
argocd app delete <app-name>        # Delete app

# === Port Forwarding ===
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0
```

---

## Next Steps

1. ✅ Infrastructure deployed
2. ✅ Argo CD running
3. 🔲 Push application to GitHub
4. 🔲 Configure Argo CD to watch your repo
5. 🔲 Make a code change and watch GitOps in action!
