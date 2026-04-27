# ===========================================
# TERRAFORM VARIABLES - DEV ENVIRONMENT
# ===========================================

aws_region   = "us-east-1"
project_name = "gitops-demo"
environment  = "dev"

# VPC
vpc_cidr             = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# EKS
kubernetes_version  = "1.35"
node_instance_types = ["t3.medium"]
node_min_size       = 1
node_max_size       = 3
node_desired_size   = 2

# Argo CD
argocd_version = "5.51.4"
