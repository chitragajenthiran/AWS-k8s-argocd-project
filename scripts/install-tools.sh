#!/bin/bash
# ===========================================
# Install DevOps Tools on Amazon Linux 2023
# ===========================================
# Run: chmod +x install-tools.sh && ./install-tools.sh

set -e

echo "=========================================="
echo "Installing DevOps Tools on Amazon Linux"
echo "=========================================="

# Update system
sudo yum update -y

# Install Git
sudo yum install -y git unzip

# Install Terraform
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum install -y terraform

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Install AWS CLI v2 (usually pre-installed on Amazon Linux 2023)
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
fi

# Install Helm
echo "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Argo CD CLI
echo "Installing Argo CD CLI..."
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Install Docker
echo "Installing Docker..."
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
helm version --short
argocd version --client
docker --version

echo ""
echo "=========================================="
echo "✅ All tools installed successfully!"
echo "=========================================="
echo ""
echo "⚠️  IMPORTANT: Log out and back in for Docker permissions"
echo "   Run: exit"
echo "   Then SSH back in"
echo ""
