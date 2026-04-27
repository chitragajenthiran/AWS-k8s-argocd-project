#!/bin/bash
# ===========================================
# Quick Deploy Script
# ===========================================
# Run after install-tools.sh

set -e

REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="gitops-demo-dev-eks"

echo "=========================================="
echo "Deploying GitOps Infrastructure"
echo "=========================================="

# Check AWS credentials
echo "Checking AWS credentials..."
aws sts get-caller-identity || { echo "❌ AWS credentials not configured"; exit 1; }

# Navigate to terraform directory
cd ~/terraform-learn/k8s-argocd-project/terraform/aws 2>/dev/null || \
cd ~/k8s-argocd-project/terraform/aws 2>/dev/null || \
{ echo "❌ Project directory not found"; exit 1; }

echo "Working directory: $(pwd)"

# Initialize Terraform
echo ""
echo "Step 1/4: Initializing Terraform..."
terraform init

# Plan
echo ""
echo "Step 2/4: Creating execution plan..."
terraform plan -out=tfplan

# Confirm
echo ""
read -p "Do you want to apply this plan? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

# Apply
echo ""
echo "Step 3/4: Applying infrastructure (this takes 15-20 minutes)..."
terraform apply tfplan

# Configure kubectl
echo ""
echo "Step 4/4: Configuring kubectl..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Verify
echo ""
echo "=========================================="
echo "Verifying deployment..."
echo "=========================================="

echo "Cluster nodes:"
kubectl get nodes

echo ""
echo "Argo CD pods:"
kubectl get pods -n argocd

echo ""
echo "=========================================="
echo "✅ Deployment Complete!"
echo "=========================================="

# Get Argo CD info
ARGOCD_URL=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)

echo ""
echo "Argo CD Access:"
echo "  URL:      http://$ARGOCD_URL"
echo "  Username: admin"
echo "  Password: $ARGOCD_PASS"
echo ""
echo "If URL shows 'pending', wait 2-3 minutes and run:"
echo "  kubectl get svc argocd-server -n argocd"
echo ""
